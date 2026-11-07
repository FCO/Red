use JSON::Fast;
use UUID;
use X::Red::Migration;
=head2 Red::Migration::Storage

unit module Red::Migration::Storage;
my Lock $registry-lock .= new;
my %mutexes;
my %owners;

#| Remove a migration staging tree recursively without traversing symbolic links. Missing paths are
#| ignored.
sub remove-tree(IO() $path) is export {
    return unless $path.e;
    if $path.d && !$path.l {
        remove-tree($_) for $path.dir;
        $path.rmdir;
    } else { $path.unlink }
}
#| Create a directory and any missing parents for migration artifacts or locking metadata.
sub make-directory(IO() $path) is export {
    return if $path.d;
    make-directory($path.parent) unless $path.parent.d;
    $path.mkdir;
}
#| Return a stable lock path outside the replaceable history directory, creating its parent when
#| necessary.
sub history-lock-path(IO() $directory --> IO::Path) is export {
    make-directory($directory.parent);
    $directory.parent.resolve.add('.' ~ $directory.basename ~ '.migration.lock')
}
#| Return the recovery journal path associated with a migration history lock.
sub journal-path(IO() $directory --> IO::Path) {
    history-lock-path($directory).extension('journal.json')
}
#| Recover an interrupted history publication from its staging and backup journal. Reject ambiguous
#| or invalid recovery paths instead of guessing.
sub recover(IO() $directory) {
    my $journal = journal-path($directory);
    return unless $journal.f;
    my %record = from-json $journal.slurp;
    my $stage = %record<stage>.IO;
    my $backup = %record<backup>.IO;
    for $stage, $backup -> $path {
        X::Red::Migration.new(:reason('Invalid migration publication journal')).throw
            unless $path.parent.resolve eq $directory.parent.resolve
                && $path.basename.starts-with('.' ~ $directory.basename ~ '.');
    }
    if !$directory.e && $backup.d { $backup.rename($directory) }
    elsif !$directory.d || ($backup.e && $stage.e) {
        X::Red::Migration.new(:reason('Incomplete migration publication requires inspection')).throw;
    }
    remove-tree($stage);
    remove-tree($backup);
    $journal.unlink;
}
#| Run a callback under the process mutex and filesystem history lock, recovering pending
#| publication first. Nested calls on the owning thread are allowed; wait=False rejects a competing
#| process immediately.
sub with-history-lock(IO() $directory, &body, Bool :$wait = True) is export {
    my $path = history-lock-path($directory);
    return body() if $registry-lock.protect({ (%owners{$path.Str} // -1) == $*THREAD.id });
    my $mutex = $registry-lock.protect: { %mutexes{$path.Str} //= Lock.new };
    $mutex.protect: {
        $registry-lock.protect({ %owners{$path.Str} = $*THREAD.id });
        LEAVE { $registry-lock.protect({ %owners{$path.Str}:delete }) }
        my $handle = $path.open(:a);
        LEAVE $handle.close if $handle.defined;
        X::Red::Migration.new(:reason('Another process is preparing or publishing migrations')).throw
            unless $handle.lock(:non-blocking(!$wait));
        recover($directory);
        body()
    }
}
#| Copy a migration history recursively into staging. Reject symbolic links so publication cannot
#| follow paths outside the supplied tree.
sub copy-tree(IO() $source, IO() $target) is export {
    X::Red::Migration.new(:reason("Migration symlinks are unsupported: $source")).throw if $source.l;
    if $source.d {
        make-directory($target);
        for $source.dir -> $path { copy-tree($path, $target.add($path.basename)) }
    } else { $source.copy($target) }
}
#| Create an isolated copy of the complete history for generation, backfill or serialization before
#| publication.
sub staging-history(IO() $directory --> IO::Path) is export {
    my $stage = $directory.parent.add('.' ~ $directory.basename ~ '.stage-' ~ UUID.new.Str);
    copy-tree($directory, $stage);
    $stage
}
#| Replace a history using a staging directory, backup and recovery journal. Restore the prior
#| history when publication fails.
sub publish-history(IO() $directory, IO() $stage) is export {
    my $backup = $directory.parent.add('.' ~ $directory.basename ~ '.backup-' ~ UUID.new.Str);
    my $journal = journal-path($directory);
    my $temporary = $journal.extension('tmp');
    $temporary.spurt(to-json(%(stage => $stage.absolute, backup => $backup.absolute)));
    $temporary.rename($journal);
    try {
        $directory.rename($backup);
        $stage.rename($directory);
        CATCH { default { recover($directory); .rethrow } }
    }
    recover($directory);
}

#| Remove a staging tree and its associated lock and journal files after validation or cleanup.
sub discard-staging-history(IO() $stage) is export {
    remove-tree($stage);
    my $lock = history-lock-path($stage);
    $lock.unlink if $lock.f;
    my $journal = journal-path($stage);
    $journal.unlink if $journal.f;
}

sub bundle-journal(IO() $project --> IO::Path) {
    $project.add('.red-bundle-publication.json')
}

sub bundle-paths(IO() $project, Str $token --> Hash) {
    X::Red::Migration.new(:reason('Invalid bundle publication token')).throw
        unless $token ~~ /^ <[0..9a..fA..F]> ** 8 '-' <[0..9a..fA..F]> ** 4 '-'
            <[0..9a..fA..F]> ** 4 '-' <[0..9a..fA..F]> ** 4 '-' <[0..9a..fA..F]> ** 12 $/;
    my $parent = $project.add('resources/red');
    X::Red::Migration.new(:reason('Bundle resources must remain inside the project')).throw
        if '..' eq any($parent.resolve.relative($project.resolve).IO.parts);
    %(root => $parent.add('migrations'), meta => $project.add('META6.json'),
        new => $parent.add(".migrations.bundle-{$token}-new"),
        old => $parent.add(".migrations.bundle-{$token}-old"),
        meta-new => $project.add(".red-bundle-{$token}-meta-new"),
        meta-old => $project.add(".red-bundle-{$token}-meta-old"))
}

sub write-bundle-journal(IO() $project, %record) {
    my $file = bundle-journal($project);
    my $temporary = $file.extension('tmp');
    $temporary.spurt(to-json(%record));
    $temporary.rename($file);
}

#| Recover both resources and META6 together. A committed publication is finalized;
#| an interrupted, uncommitted one is rolled back. Call under with-bundle-lock.
sub recover-bundle(IO() $project) is export {
    my $journal = bundle-journal($project);
    return unless $journal.e;
    X::Red::Migration.new(:reason('Bundle journal cannot be a symlink')).throw if $journal.l;
    my %record = from-json($journal.slurp);
    X::Red::Migration.new(:reason('Invalid bundle publication journal')).throw
        unless (%record<format> // 0) == 1 && %record<token> ~~ Str
            && %record<had-root> ~~ Bool:D
            && (%record<state> // '') eq any(<prepared rolling-back rolled-back committed>);
    my %paths = bundle-paths($project, %record<token>);
    X::Red::Migration.new(:reason('Bundle recovery paths cannot be symlinks')).throw
        if %paths.values.grep(*.l);
    if %record<state> eq any(<committed rolled-back>) {
        X::Red::Migration.new(:reason('Committed bundle is incomplete')).throw
            unless %paths<meta>.f && (%record<state> eq 'committed'
                ?? %paths<root>.d !! (so %paths<root>.d) == %record<had-root>);
    } else {
        X::Red::Migration.new(:reason('Missing original META6 backup; inspect bundle journal')).throw
            unless %paths<meta-old>.f;
        if %record<state> eq 'prepared' && %record<had-root> && !%paths<old>.d {
            X::Red::Migration.new(:reason('Ambiguous bundle recovery; inspect journal')).throw
                unless %paths<root>.d && %paths<new>.d;
        }
        %record<state> = 'rolling-back';
        write-bundle-journal($project, %record);
        if %paths<old>.d {
            remove-tree(%paths<root>);
            %paths<old>.rename(%paths<root>);
        } elsif !%record<had-root> {
            remove-tree(%paths<root>);
        }
        my $restore = %paths<meta-new>;
        $restore.unlink if $restore.e;
        %paths<meta-old>.copy($restore);
        $restore.rename(%paths<meta>);
        %record<state> = 'rolled-back';
        write-bundle-journal($project, %record);
    }
    remove-tree(%paths{$_}) for <new old>;
    for <meta-new meta-old> -> $key {
        %paths{$key}.unlink if %paths{$key}.e;
    }
    $journal.unlink;
}

#| Serialize project-wide publications and recover a previous interrupted bundle first.
sub with-bundle-lock(IO() $project, &body) is export {
    with-history-lock($project.add('.red-bundle'), {
        recover-bundle($project);
        body()
    })
}

#| Publish a staged resource tree and metadata as one recoverable operation. The optional
#| checkpoint callback permits subprocess crash tests without production environment flags.
sub publish-bundle(IO() $project, IO() $stage, IO() $metadata,
                   Callable :$checkpoint = -> Str $phase { }) is export {
    my $token = UUID.new.Str;
    my %paths = bundle-paths($project, $token);
    make-directory(%paths<root>.parent);
    X::Red::Migration.new(:reason('Bundle targets cannot be symlinks')).throw
        if %paths<root>.l || %paths<meta>.l;
    X::Red::Migration.new(:reason('Bundle staging files must be regular local artifacts')).throw
        unless $stage.d && !$stage.l && $metadata.f && !$metadata.l;
    LEAVE {
        unless bundle-journal($project).e {
            remove-tree(%paths{$_}) for <new old>;
            for <meta-new meta-old> -> $key { %paths{$key}.unlink if %paths{$key}.e }
        }
    }
    my $had-root = so %paths<root>.d;
    %paths<meta>.copy(%paths<meta-old>);
    $metadata.rename(%paths<meta-new>);
    $stage.rename(%paths<new>);
    my %record = format => 1, :$token, :$had-root, state => 'prepared';
    write-bundle-journal($project, %record);
    try {
        $checkpoint('prepared');
        %paths<root>.rename(%paths<old>) if $had-root;
        $checkpoint('resources-backed-up');
        %paths<new>.rename(%paths<root>);
        $checkpoint('resources-published');
        %paths<meta-new>.rename(%paths<meta>);
        $checkpoint('metadata-published');
        %record<state> = 'committed';
        write-bundle-journal($project, %record);
        $checkpoint('committed');
        CATCH { default { recover-bundle($project); .rethrow } }
    }
    recover-bundle($project);
}
