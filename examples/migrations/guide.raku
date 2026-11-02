#!/usr/bin/env raku
use lib $?FILE.IO.parent.Str;
use Workshop;
use JSON::Fast;
use nqp;

my $assets = (%*ENV<WORKSHOP_ASSETS> // '/opt/workshop').IO;
my $action = @*ARGS.shift // 'status';
my $yes = so @*ARGS.grep(* eq '--yes');
my $root = ($action eq 'init'
    ?? (@*ARGS.first(* ne '--yes') // %*ENV<WORKSHOP_WORKSPACE> // '/workspace').IO
    !! $?FILE.IO.parent).absolute.IO;
my $state-file = $root.add('.tutorial-state.json');

sub model(Int $stage, Str $variant = 'main' --> Str) {
    my @fields;
    @fields.push('Str description') if $stage >= 2;
    if $stage >= 3 {
        @fields.push($variant eq 'conflict' ?? 'Int owner' !! 'Str owner')
            if $variant ne 'priority';
        @fields.push('Int priority') if $variant eq any('main', 'priority');
    }
    "use Red;\nunit model Task is table<task>;\nhas Int \$.id is serial;\n"
        ~ "has Str \$.title is column;\n"
        ~ @fields.map({ 'has ' ~ .words[0] ~ ' $.' ~ .words[1]
            ~ (.words[1] eq 'description' ?? ' is column;' !! ' is column{ :nullable };') ~ "\n" }).join
}
sub fingerprints(IO::Path $directory --> Hash) {
    my %files;
    sub visit(IO::Path $path) {
        die "Symbolic links are unsupported: $path" if $path.l;
        if $path.d { visit($_) for $path.dir.grep(*.basename ne '.precomp') }
        else { %files{$path.relative($directory)} = nqp::sha1($path.slurp) }
    }
    visit($directory) if $directory.d;
    %files
}
sub read-state(IO::Path $directory --> Hash) {
    my $file = $directory.add('.tutorial-state.json');
    die "Workspace is not initialized: $directory" unless $file.f;
    my %state = from-json($file.slurp);
    die 'Unsupported tutorial state' unless %state<format> == 1
        && %state<stage> ~~ Int && 1 <= %state<stage> <= 3;
    %state
}
sub history-fingerprint(IO::Path $directory --> Str) {
    my %files = fingerprints($directory.add('migrations'));
    nqp::sha1(%files.keys.sort.map({ $_ ~ ':' ~ %files{$_} }).join("\n"))
}
sub save-state(IO::Path $directory, %state) {
    my $temporary = $directory.add('.tutorial-state.json.tmp');
    $temporary.spurt(to-json(%state));
    $temporary.rename($directory.add('.tutorial-state.json'));
}
sub check-files(IO::Path $directory, %state) {
    for %state<files>.kv -> $name, $hash {
        die "Invalid managed path: $name" if $name.IO.is-absolute || $name.split('/').grep(* eq '..');
        my $file = $directory.add($name);
        die "Local edits would be overwritten: $file. Preserve your edits before advancing."
            unless $file.f && !$file.l && nqp::sha1($file.slurp) eq $hash;
    }
}
sub advance(IO::Path $directory, %state, Int $stage, Str $variant = 'main') {
    $directory.add('lib/Task.rakumod').spurt(model($stage, $variant));
    %state<files><lib/Task.rakumod> = nqp::sha1($directory.add('lib/Task.rakumod').slurp);
    %state<stage> = $stage;
    %state<variant> = $variant;
    $directory.add('tutorial').chmod(0o755);
    save-state($directory, %state);
}
sub confirm(Str $message) {
    say $message;
    return if $yes;
    print 'Press Enter to continue (EOF stops): ';
    $*OUT.flush;
    die 'Stopped; all files were preserved.' unless $*IN.get.defined;
}
sub migration-copies(@sources, IO::Path $target, Bool :$apply = False --> Int) {
    my %known = fingerprints($target.add('migrations'));
    my @pending;
    for @sources -> $source {
        my %incoming = fingerprints($source.add('migrations'));
        for %incoming.keys.sort -> $name {
            if %known{$name}:exists {
                die "Different migration files share the same path: $name"
                    unless %known{$name} eq %incoming{$name};
            } else {
                @pending.push([$source.add('migrations').add($name), $target.add('migrations').add($name)]);
                %known{$name} = %incoming{$name};
            }
        }
    }
    if $apply { copy-tree(.[0], .[1]) for @pending }
    @pending.elems
}

given $action {
    when 'init' {
        if $state-file.f {
            my %state = read-state($root);
            say "Existing step {%state<stage>} retained; workspace and migrations preserved.";
        } else {
            die "Refusing to replace an unrecognized workspace: $root"
                if $root.e && (!$root.d || $root.l || $root.dir.elems);
            make-directory($root);
            copy-tree($assets.add('template'), $root);
            make-directory($root.add('lib'));
            $root.add('lib/Task.rakumod').spurt(model(1));
            $assets.add('guide.raku').copy($root.add('tutorial'));
            $assets.add('Workshop.rakumod').copy($root.add('Workshop.rakumod'));
            $root.add('tutorial').chmod(0o755);
            my $red = (%*ENV<WORKSHOP_RED_SOURCE> // '/opt/red').IO;
            for <lib bin META6.json README.md LICENSE> -> $name {
                copy-tree($red.add($name), $root.add("vendor/Red/$name")) if $red.add($name).e;
            }
            save-state($root, %(format => 1, stage => 1, variant => 'main', files => fingerprints($root)));
            say 'Step 1 is ready. Run red migration prepare initial, review the SQL, then red migration apply.';
        }
    }
    when 'ready' { read-state($root); }
    when 'status' {
        my %state = read-state($root);
        say "Current step: {%state<stage>} ({%state<variant>})\nDatabase state: run red migration status separately.";
    }
    when 'next' | 'preview' {
        my %state = read-state($root);
        die 'This is a parallel workspace; integrate it from the main workspace.' unless %state<variant> eq 'main';
        my $requested = @*ARGS.first(*.starts-with('--to='));
        if $requested.defined {
            my $target = $requested.substr(5);
            die 'Use --to=2 or --to=3.' unless $target eq any('2', '3');
            if %state<stage> == $target.Int {
                say "Already at step $target; code and migrations preserved.";
                exit 0;
            }
            die "Expected step {$target.Int - 1}, but this workspace is at step {%state<stage>}. "
                ~ 'Use ./tutorial status and resume the matching chapter; no files were changed.'
                unless %state<stage> + 1 == $target.Int;
        }
        die 'You are at the final step.' if %state<stage> == 3;
        check-files($root, %state);
        my $next = %state<stage> + 1;
        say "Current step: {%state<stage>}; next code step: $next.";
        say model($next);
        if $action eq 'next' {
            confirm("Advance code to step $next. Migration files and databases will remain untouched.");
            advance($root, %state, $next);
            say "Step $next is ready. Run red migration prepare to generate its migration.";
        }
    }
    when 'parallel' | 'integrate' | 'conflict' {
        my %state = read-state($root);
        check-files($root, %state);
        my $base = (%*ENV<WORKSHOP_CHECKOUTS> // $root.parent.add('parallel').Str).IO;
        if $action eq 'parallel' {
            die 'Create parallel workspaces from step 2.' unless %state<stage> == 2;
            die 'Prepare the shared migration history first.' unless fingerprints($root.add('migrations'));
            for <owner priority conflict> -> $name {
                die "Parallel workspace already exists: {$base.add($name)}" if $base.add($name).e;
            }
            confirm("Create three independent step-3 workspaces in $base.");
            for <owner priority conflict> -> $variant {
                my $target = $base.add($variant);
                copy-tree($root, $target);
                my %branch = read-state($target);
                %branch<base-history> = history-fingerprint($root);
                advance($target, %branch, 3, $variant);
                say "$variant: $target";
            }
        } elsif $action eq 'integrate' {
            die 'Integrate parallel versions into the main step-2 workspace.' unless %state<stage> == 2;
            my @branches = <owner priority>.map({ $base.add($_) });
            for @branches -> $branch {
                my %branch-state = read-state($branch);
                check-files($branch, %branch-state);
                die "Parallel workspace has a different shared history: $branch"
                    unless %branch-state<variant> eq $branch.basename
                        && (%branch-state<base-history> // '') eq history-fingerprint($root);
                die "Prepare a migration in $branch before integrating."
                    unless migration-copies([$branch], $root) > 0;
            }
            migration-copies(@branches, $root);
            confirm('Combine both code changes and prepared migrations. Run red migration serialize afterward.');
            migration-copies(@branches, $root, :apply);
            advance($root, %state, 3);
            say 'Step 3 code is ready. The migration fork still needs red migration serialize.';
        } else {
            my $target = $base.add('conflict-demo');
            die "Workspace already exists: $target" if $target.e;
            for <owner conflict> -> $name { check-files($base.add($name), read-state($base.add($name))) }
            confirm('Create an isolated incompatible migration history; production stays unchanged.');
            copy-tree($base.add('owner'), $target);
            $target.add('tutorial').chmod(0o755);
            migration-copies([$base.add('conflict')], $target, :apply);
            say "Conflict demonstration: $target";
        }
    }
    default { die 'Usage: ./tutorial status|preview|next|parallel|integrate|conflict [--yes] [--to=2|3]' }
}
CATCH { default { note .message; exit 1 } }
