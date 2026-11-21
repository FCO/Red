#!/usr/bin/env raku
use v6.d;
use JSON::Fast;
use UUID;

# Scenario data contains only Raku code and documented shell command strings.
# Source guards prevent an edited example from silently using an old test fixture.
my IO::Path $ROOT = $?FILE.IO.resolve.parent.parent;

sub make-directory(IO::Path $path) {
    return if $path.d;
    make-directory($path.parent) unless $path.parent.d;
    $path.mkdir;
}

sub remove-tree(IO::Path $path) {
    return unless $path.e;
    if $path.d && !$path.l {
        remove-tree($_) for $path.dir;
        $path.rmdir;
    } else {
        $path.unlink;
    }
}

sub copy-tree(IO::Path $from, IO::Path $to) {
    make-directory($to);
    for $from.dir -> $entry {
        next if $entry.basename eq '.precomp' || $entry.extension eq any(<db sqlite>);
        my $target = $to.add($entry.basename);
        $entry.d ?? copy-tree($entry, $target) !! $entry.copy($target);
    }
}

sub snippets(IO::Path $path --> Array) {
    my @blocks;
    my @lines;
    my Bool $inside = False;
    for $path.lines -> $line {
        if $line.starts-with('```') {
            if $inside {
                @blocks.push(@lines.join("\n") ~ "\n");
                @lines = ();
            }
            $inside = !$inside;
        } elsif $inside {
            @lines.push($line);
        }
    }
    @blocks.Array
}

sub invoke(@command, IO::Path :$cwd = $ROOT, :%environment = %*ENV.Hash,
    Int :$timeout = 240 --> Hash) {
    my $process = Proc::Async.new(|@command);
    my Str $output = '';
    my $lock = Lock.new;
    my &record = -> $chunk { $lock.protect({ $output ~= $chunk }) };
    $process.stdout.tap(&record);
    $process.stderr.tap(&record);
    my $done = $process.start(:$cwd, :ENV(%environment));
    await Promise.anyof($done, Promise.in($timeout));
    unless $done.status {
        $process.kill(SIGKILL);
        await $done;
        return %(status => 'timeout', log => $output);
    }
    my $exit = (await $done).exitcode;
    my Bool $failed = so $output.lines.first(*.starts-with('not ok'));
    %(status => $exit == 0 && !$failed ?? 'passed' !! 'failed', log => $output)
}

sub MAIN(Str :$output = 'test-results/doc-examples', Str :$match = '',
    Str :$pg-workspace = '', Str :$resume-from = '', Bool :$inventory-only = False) {
    my @cases = from-json($ROOT.add('tools/doc-examples.json').slurp).list;
    my IO::Path $destination = $output.IO.is-absolute ?? $output.IO !! $ROOT.add($output);
    make-directory($destination);
    my %blocks;
    my %previous;
    if $resume-from.chars {
        my $previous = $resume-from.IO;
        if $previous.add('results.json').f {
            for from-json($previous.add('results.json').slurp).list -> %result {
                %previous{%result<name>} = %result if %result<status> eq 'passed';
            }
        }
    }
    my @results;
    for @cases -> %case {
        my Str $name = %case<name>;
        next if $match.chars && !$name.contains($match);
        my @changed;
        for %case<sources>.list -> %source {
            my Str $file = %source<file>;
            %blocks{$file} //= snippets($ROOT.add($file));
            my $actual = %blocks{$file}[%source<block> - 1] // '';
            @changed.push("$file:{%source<block>}")
                unless $actual.trim eq %source<expected>.trim;
        }
        if @changed {
            @results.push(%(:$name, status => 'changed-source',
                reason => @changed.join(', '), refs => %case<refs>, kind => %case<kind>));
            say "changed-source $name: {@changed.join(', ')}";
            next;
        }
        next if $inventory-only;
        my IO::Path $previous-code = $resume-from.chars ?? $resume-from.IO.add("$name.raku") !! $*TMPDIR.add("no-red-doc-resume");
        if %previous{$name}:exists && $previous-code.f
            && $previous-code.slurp eq %case<code> {
            my %result = %previous{$name}.Hash;
            %result<kind> = %case<kind>;
            %result<reused-from> = $resume-from;
            @results.push(%result);
            $resume-from.IO.add("$name.log").copy($destination.add("$name.log"));
            $destination.add("$name.raku").spurt(%case<code>);
            say "passed  $name (unchanged)";
            next;
        }
        if %case<requires>.defined && !%*ENV{%case<requires>} {
            @results.push(%(:$name, status => 'blocked', reason => %case<requires>,
                refs => %case<refs>, kind => %case<kind>));
            say "blocked $name ({%case<requires>})";
            next;
        }
        my IO::Path $temporary = $*TMPDIR.add('red-doc-' ~ UUID.new.Str);
        make-directory($temporary);
        LEAVE remove-tree($temporary) if $temporary.defined && $temporary.e;
        copy-tree($ROOT.add(%case<copy>), $temporary) if %case<copy>.defined;
        for (%case<files> // {}).kv -> $relative, $content {
            my $file = $temporary.add($relative);
            make-directory($file.parent);
            $file.spurt($content);
        }
        my Bool $shell = so %case<kind> eq any(<shell shell-syntax>);
        my IO::Path $script = $temporary.add($shell ?? 'example.bash' !! 'example.raku');
        my Str $code = %case<code>;
        my %environment = %*ENV.Hash;
        %environment<RED_MIGRATION_TEST>:delete;
        %environment<RED_DOC_ROOT> = $ROOT.Str;
        %environment{.key} = .value for (%case<environment> // {}).pairs;
        my $wrappers = $temporary.add('bin');
        make-directory($wrappers);
        $wrappers.add('red').spurt(qq:to/WRAPPER/);
#!/bin/sh
exec raku -I"$ROOT/lib" "$ROOT/bin/red" "\$@"
WRAPPER
        $wrappers.add('red').chmod(0o755);
        %environment<PATH> = $wrappers.Str ~ ':' ~ %environment<PATH>;
        my @command = $shell
            ?? ('bash', |(' -n'.trim if %case<kind> eq 'shell-syntax'), $script.Str)
            !! ($*EXECUTABLE.Str, '-I' ~ $ROOT.add('lib'),
                '-I' ~ $temporary.add('lib'),
                |('-I' ~ $ROOT.parent.add('Red-Driver-' ~ %case<driver>).add('lib')
                    if %case<driver>.defined), $script.Str);
        my Str $pg-database = '';
        if $pg-workspace.chars && (%case<driver> // '') eq 'Pg' {
            $pg-database = 'red_doc_' ~ UUID.new.Str.subst('-', '', :g).lc;
            my %created = invoke(['docker', 'exec', 'red-doc-pg', 'createdb',
                '-U', 'red_test', $pg-database]);
            die %created<log> unless %created<status> eq 'passed';
            $code .= subst(':dbname<red_example>', ':dbname(%*ENV<PGDATABASE>)', :g);
            $code .= subst(":dbname('red_example')", ':dbname(%*ENV<PGDATABASE>)', :g);
            @command = 'docker', 'run', '--rm', '--name', $pg-database,
                '--network', 'container:red-doc-pg',
                '-e', 'PGUSER=red_test', '-e', 'PGPASSWORD=red_doc_test',
                '-e', "PGDATABASE=$pg-database",
                |(%case<environment> // {}).pairs.map({ ('-e', "{.key}={.value}") }).flat,
                '-v', "{$temporary.resolve}:/scenario", '-v', "$pg-workspace:/work",
                '-w', '/scenario', '--entrypoint', 'raku',
                %case<image> // 'red-migrations-dev:local',
                '-I/work/Red/lib', '-I/work/Pg/lib', '-I/scenario/lib',
                '/scenario/example.raku';
        }
        $script.spurt($code);
        my $started = now;
        my %execution = invoke(@command, :cwd($temporary), :%environment,
            :timeout(%case<timeout> // 240));
        if $pg-database.chars {
            invoke(['docker', 'rm', '-f', $pg-database]);
            my %cleanup = invoke(['docker', 'exec', 'red-doc-pg', 'dropdb',
                '--force', '-U', 'red_test', $pg-database]);
            if %cleanup<status> ne 'passed' {
                %execution<status> = 'failed';
                %execution<log> ~= "\nCleanup failed: " ~ %cleanup<log>;
            }
        }
        my %result = :$name, :kind(%case<kind>), :refs(%case<refs>),
            :status(%execution<status>), :seconds((now - $started).round(0.01));
        @results.push(%result);
        $destination.add("$name.log").spurt(%execution<log>);
        $destination.add("$name.raku").spurt(%case<code>);
        say "{%execution<status>}  $name";
        $*OUT.flush;
    }
    $destination.add('results.json').spurt(to-json(@results, :sorted-keys));
    my %counts = @results.map(*.<status>).Bag.Hash;
    say to-json(%counts, :!pretty);
    exit so @results.first({ .<status> ne 'passed' });
}
