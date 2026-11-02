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
