#!/usr/bin/env raku
use lib $?FILE.IO.parent.Str;
use Workshop;
my $root = (%*ENV<WORKSHOP_WORKSPACE> // '/workspace').IO;
my $initial = '/opt/workshop/initial'.IO;
make-directory((%*ENV<WORKSHOP_CHECKOUTS> // '/parallel').IO);
if $root.add('.tutorial-state.json').f {
    my %status = command([$*EXECUTABLE.Str, $root.add('tutorial').Str, 'status'], :check);
    print %status<out>;
    say 'Existing code and migration files preserved.';
} else {
    die "Workspace is not empty and is not recognized: $root. Use a fresh workspace; existing files were preserved."
        if $root.e && (!$root.d || $root.l || $root.dir.elems);
    make-directory($root);
    for $initial.dir.grep(*.basename ne '.tutorial-state.json') -> $file {
        copy-tree($file, $root.add($file.basename));
    }
    $root.add('tutorial').chmod(0o755);
    $initial.add('.tutorial-state.json').copy($root.add('.tutorial-state.json'));
    say 'Step 1 is ready. Enter dev and run ./tutorial status.';
}
my $sleeper = Proc::Async.new('sleep', 'infinity');
my $done = $sleeper.start;
my @signals = (SIGTERM, SIGINT).map(-> $signal { signal($signal).tap({ $sleeper.kill($signal) }) });
await $done;
.close for @signals;
CATCH { default { note .message; exit 1 } }
