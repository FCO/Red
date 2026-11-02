#!/usr/bin/env raku
use lib $?FILE.IO.parent.Str;
use Workshop;
my %host-environment = %*ENV;

# Execute the marked README commands in one isolated Compose project.
sub MAIN(Bool :$keep = False) {
    my Int $status = 1;
    walkthrough($status, :$keep);
    say $status == 0 ?? 'Workshop passed: all documented chapters completed.'
        !! 'Workshop failed; inspect transcript.log.';
    exit $status;
}

sub walkthrough(Int $status is rw, Bool :$keep = False) {
    my $source = $?FILE.IO.parent.resolve;
    my $root = unique-directory('red-migration-workshop');
    my $project = 'red-workshop-' ~ $root.basename.split('-')[*-1];
    my %*ENV = %host-environment;
    %*ENV<COMPOSE_PROJECT_NAME> = $project;
    %*ENV<RED_SOURCE> = $source.parent.parent.Str;
    %*ENV<PWD> = $source.Str;
    # Reserve both ports at once, ensuring two distinct available ports.
    my $dev = IO::Socket::INET.new(:localhost<127.0.0.1>, :localport(0), :listen);
    my $prod = IO::Socket::INET.new(:localhost<127.0.0.1>, :localport(0), :listen);
    %*ENV<DEV_PORT> = $dev.localport.Str;
    %*ENV<PROD_PORT> = $prod.localport.Str;
    $dev.close; $prod.close;
    my @blocks = steps($source.add('README.md'));
    die "Expected 11 executable blocks, found {@blocks.elems}" unless @blocks.elems == 11;
    die 'Bootstrap must be the only host block' unless @blocks.head<context> eq 'host'
        && @blocks.skip.grep(*.<context> ne 'dev').elems == 0;
    my $script = "set -euo pipefail\n";
    $script ~= @blocks.head<source> ~ "\n";
    my $inside = "set -euo pipefail\n";
    for @blocks.skip.kv -> $index, %block {
        $inside ~= "\nprintf '\\n=== In-container workshop step {$index + 1} ===\\n'\n{%block<source>}\n";
        $inside ~= "\nprintf '%s\\n' {$index + 1} >> "
            ~ '"$WORKSHOP_CHECKOUTS/.walkthrough-completed"' ~ "\n";
    }
    my $inside-file = $root.add('walkthrough-commands.bash');
    $inside-file.spurt($inside);
    # Nested docker compose exec commands must not consume the remaining document
    # from stdin. Copy the script into dev; project files stay inside the container.
    $script ~= 'docker compose cp ' ~ $inside-file.Str
        ~ ' dev:/tmp/walkthrough-commands.bash' ~ "\n";
    $script ~= 'docker compose exec -T dev bash /tmp/walkthrough-commands.bash' ~ "\n";
    my $commands = $root.add('commands.bash');
    $commands.spurt($script);
    say "Project: $project\nFiles: $root";
    LEAVE {
        if $keep {
            my @keys = <COMPOSE_PROJECT_NAME RED_SOURCE DEV_PORT PROD_PORT>;
            $root.add('compose.env').spurt(@keys.map({ "$_={%*ENV{$_}}" }).join("\n") ~ "\n");
            say "Resources retained. Compose settings: {$root.add('compose.env')}";
        } else {
            my %cleanup = command(['docker', 'compose', '--profile', '*', 'down', '-v', '--remove-orphans'], :cwd($source));
            print %cleanup<out>; note %cleanup<err> if %cleanup<err>.chars;
            $status = %cleanup<status> if %cleanup<status>;
            for <v1 v2 v3> -> $release {
                command(['docker', 'image', 'rm', "{$project}-release:$release"]);
            }
            command(['docker', 'image', 'rm', "{$project}-ci:local"]);
            if $status == 0 { remove-tree($root) }
            else { say "Failed run retained for diagnosis: $root" }
        }
    }
    my $log = $root.add('transcript.log').open(:w);
    my $lock = Lock.new;
    my $process = Proc::Async.new('bash', $commands.Str);
    my &record = -> $text {
        $lock.protect: { $*OUT.print($text); $*OUT.flush; $log.print($text); $log.flush }
    };
    $process.stdout.tap(&record);
    $process.stderr.tap(&record);
    my $done = $process.start(:cwd($source), :ENV(%*ENV));
    my $interrupted = False;
    my $interrupt = signal(SIGINT).tap({ $interrupted = True; $process.kill(SIGTERM) });
    $status = (await $done).exitcode;
    $interrupt.close;
    $log.close;
    $status = 130 if $interrupted;
    if $status == 0 {
        my %logs = command(['docker', 'compose', '--profile', 'production', 'logs',
            '--no-color', 'dev', 'prod'], :cwd($source));
        if %logs<status> || (%logs<out> ~ %logs<err>).contains('falling back') {
            note "Application must render without symbolic-evaluation fallback:\n{%logs<out>}{%logs<err>}";
            $status = 1;
        }
    }
    my %completion = command(['docker', 'compose', 'exec', '-T', 'dev',
        'cat', '/parallel/.walkthrough-completed'], :cwd($source));
    my @completed = %completion<out>.lines;
    unless @completed.Array eqv (1..10).map(*.Str).Array {
        note "Not all document steps completed: {@completed.join(', ')}";
        $status = 1;
    }
}
CATCH { default { note .message; exit 1 } }
