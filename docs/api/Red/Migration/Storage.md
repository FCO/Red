Red::Migration::Storage
-----------------------

### sub remove-tree

```raku
sub remove-tree(
    IO(Any) $path
) returns Mu
```

Remove a migration staging tree recursively without traversing symbolic links. Missing paths are ignored.

### sub make-directory

```raku
sub make-directory(
    IO(Any) $path
) returns Mu
```

Create a directory and any missing parents for migration artifacts or locking metadata.

### sub history-lock-path

```raku
sub history-lock-path(
    IO(Any) $directory
) returns IO::Path
```

Return a stable lock path outside the replaceable history directory, creating its parent when necessary.

### sub journal-path

```raku
sub journal-path(
    IO(Any) $directory
) returns IO::Path
```

Return the recovery journal path associated with a migration history lock.

### sub recover

```raku
sub recover(
    IO(Any) $directory
) returns Mu
```

Recover an interrupted history publication from its staging and backup journal. Reject ambiguous or invalid recovery paths instead of guessing.

### sub with-history-lock

```raku
sub with-history-lock(
    IO(Any) $directory,
    &body,
    Bool :$wait = Bool::True
) returns Mu
```

Run a callback under the process mutex and filesystem history lock, recovering pending publication first. Nested calls on the owning thread are allowed; wait=False rejects a competing process immediately.

### sub copy-tree

```raku
sub copy-tree(
    IO(Any) $source,
    IO(Any) $target
) returns Mu
```

Copy a migration history recursively into staging. Reject symbolic links so publication cannot follow paths outside the supplied tree.

### sub staging-history

```raku
sub staging-history(
    IO(Any) $directory
) returns IO::Path
```

Create an isolated copy of the complete history for generation, backfill or serialization before publication.

### sub publish-history

```raku
sub publish-history(
    IO(Any) $directory,
    IO(Any) $stage
) returns Mu
```

Replace a history using a staging directory, backup and recovery journal. Restore the prior history when publication fails.

### sub discard-staging-history

```raku
sub discard-staging-history(
    IO(Any) $stage
) returns Mu
```

Remove a staging tree and its associated lock and journal files after validation or cleanup.

