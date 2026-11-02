#!/usr/bin/env raku
use lib $?FILE.IO.parent.Str;
use Workshop;

# In-container conveniences. All migration and deployment actions remain in the document.
my @arguments = @*ARGS;
my $action = @arguments.shift // '';
my $curl = %*ENV<WORKSHOP_CURL>
    // ($*KERNEL.name.lc eq 'darwin' ?? '/usr/bin/curl' !! 'curl');
sub execute(*@args) { exit (run |@args).exitcode }
sub compose-directory() {
    my $root = %*ENV<WORKSHOP_ROOT> // $?FILE.IO.parent.resolve.Str;
    %*ENV<PWD> = $root;
    chdir $root;
}
sub checked(*@args) {
    my $result = run |@args;
    die "Command failed (exit {$result.exitcode}): {@args.join(' ')}" if $result.exitcode;
}
sub build-project(Str $image) {
    my $workspace = %*ENV<WORKSHOP_WORKSPACE> // '/workspace';
    checked('docker', 'build', '--build-arg', 'DEV_IMAGE=red-migrations-dev:local',
        '-t', $image, '-f', "$workspace/release.Dockerfile", $workspace);
}
given $action {
    when 'migration-id' {
        my $name = @arguments.shift // die 'Usage: workshop migration-id NAME';
        my $directory = $*CWD.add('migrations');
        my @matches = $directory.d ?? $directory.dir.grep({
            .d && .basename.chars >= 28 && .basename.substr(26, 1) eq '-'
                && .basename.substr(27) eq $name
                && .basename.substr(0, 26) ~~ /^ <[0..9A..Z]> ** 26 $/
        }) !! ();
        die "No migration named '$name' in $directory. "
            ~ 'Check your working directory and complete the preceding preparation/integration steps.'
            unless @matches;
        die "Multiple migrations named '$name' in $directory; inspect the history before continuing."
            unless @matches.elems == 1;
        say @matches[0].basename.substr(0, 26);
    }
    when 'check' {
        my $description = @arguments.shift // die 'Usage: workshop check DESCRIPTION COMMAND ...';
        die 'A check command is required.' unless @arguments;
        my $status = (run |@arguments).exitcode;
        say ($status == 0 ?? 'ok' !! 'nok') ~ " - $description";
        exit ($status < 0 ?? 1 !! $status);
    }
    when 'start' {
        compose-directory();
        checked('docker', 'compose', 'exec', '-d', 'dev', 'bash', '-c',
            'echo $$ > /tmp/task-server.pid; exec raku -Ilib app.raku');
        checked($*EXECUTABLE, $?FILE, 'wait-http', 'http://dev:8080/health');
        say "Development application is ready at http://localhost:{%*ENV<DEV_PORT> // 8081}/.";
    }
    when 'rollback' {
        my $from = @arguments.shift // die 'Usage: workshop rollback CURRENT PREVIOUS';
        my $to = @arguments.shift // die 'Usage: workshop rollback CURRENT PREVIOUS';
        compose-directory();
        %*ENV<RELEASE> = $from;
        checked('docker', 'compose', 'stop', 'prod');
        checked('docker', 'compose', 'run', '--rm', 'migrate', 'red', 'migration', 'rollback');
        %*ENV<RELEASE> = $to;
        checked('docker', 'compose', 'up', '-d', '--wait', 'prod');
        say "Production migration reverted; release $to is running.";
    }
    when 'compose' {
        compose-directory();
        if 'run' eq any(@arguments) && 'ci' eq any(@arguments) {
            my $project = %*ENV<COMPOSE_PROJECT_NAME> // 'red-workshop';
            %*ENV<CI_IMAGE> = "{$project}-ci:local";
            build-project(%*ENV<CI_IMAGE>);
        }
        execute('docker', 'compose', |@arguments)
    }
    when 'dev' { execute('docker', 'compose', 'exec', '-T', 'dev', 'bash', '-se') }
    when 'curl' { execute($curl, |@arguments) }
    when 'build-release' {
        my $version = @arguments.shift // die 'A release version is required.';
        my $project = %*ENV<COMPOSE_PROJECT_NAME> // 'red-workshop';
        build-project("{$project}-release:$version");
    }
    when 'deploy' {
        my $version = @arguments.shift // die 'A release version is required: deploy v1';
        die 'Release names may contain only letters, digits, dots, underscores and hyphens.'
            unless $version ~~ /^ <[A..Za..z0..9_.-]>+ $/;
        my $project = %*ENV<COMPOSE_PROJECT_NAME> // 'red-workshop';
        compose-directory();
        %*ENV<RELEASE> = $version;
        %*ENV<CI_IMAGE> = "{$project}-release:$version";
        build-project(%*ENV<CI_IMAGE>);
        checked('docker', 'compose', 'run', '--rm', 'ci');
        checked('docker', 'compose', 'stop', 'prod');
        checked('docker', 'compose', 'run', '--rm', 'migrate');
        checked('docker', 'compose', 'up', '-d', '--wait', 'prod');
        say "Release $version deployed. The workspace was not modified.";
    }
    when 'expect-failure' {
        my $pattern = @arguments.shift // die 'An error pattern is required.';
        my Str $input;
        if @arguments.head eq '--stdin' {
            @arguments.shift;
            $input = $*IN.slurp;
        }
        if @arguments.head eq 'dc' {
            compose-directory();
            @arguments = 'docker', 'compose', |@arguments.skip;
        }
        my %result = command(@arguments, :$input);
        print %result<out>;
        note %result<err> if %result<err>.chars;
        die 'Expected failure, but the command succeeded.' unless %result<status>;
        # Use grep's documented extended-regex syntax, rather than interpreting shell text as Raku.
        my %match = command(['grep', '-Eiq', $pattern], :input(%result<out> ~ %result<err>));
        exit %match<status>;
    }
    when 'wait-http' {
        my $url = @arguments.shift // die 'An HTTP URL is required.';
        for ^120 {
            exit 0 unless command([$curl, '-fsS', $url])<status>;
            sleep 1;
        }
        die "HTTP did not become ready: $url";
    }
    default { die 'Usage: workshop check|migration-id|start|deploy|rollback|compose|expect-failure|wait-http ...' }
}
CATCH { default { note .message; exit 1 } }
