Red::Migration::Manager
-----------------------

class Red::Migration::Manager::Translation
------------------------------------------

Provide access to a driver type's pure translation methods while forbidding SQL execution.

### method FALLBACK

```raku
method FALLBACK(
    Str $method,
    |args
) returns Mu
```

Delegate dialect-specific translation to the backend type without constructing a database connection.

### method execute

```raku
method execute(
    |
) returns Mu
```

Reject SQL execution through the translation-only adapter. Preparing migration artifacts must remain offline.

### method error

```raku
method error(
    Str $reason
) returns Mu
```

Raise X::Red::Migration with an actionable explanation of an invalid migration or execution state.

### method checksum

```raku
method checksum(
    Str $source
) returns Str
```

Compute the integrity fingerprint used for historical snapshots, source files and generated SQL.

### method execute

```raku
method execute(
    $db,
    Str $sql
) returns Mu
```

Execute one SQL statement and finish its cursor before committing or releasing the connection.

### method row

```raku
method row(
    $db,
    Str $sql,
    *@bind
) returns Mu
```

Execute a query with bind values, return its first row and release the result cursor.

### method load

```raku
method load(
    IO(Any) $path
) returns Mu
```

Load a trusted Raku configuration artifact and extract its plain migration metadata when applicable.

### method driver

```raku
method driver(
    Str $name
) returns Mu
```

Resolve a supported SQL backend for offline translation; no target connection is constructed.

### method connection

```raku
method connection(
    Str $name
) returns Mu
```

Resolve a configured connection or lazy factory. A disposable test context overrides the normal target.

### method dialect

```raku
method dialect(
    $db
) returns Str
```

Return the supported migration dialect for a concrete database driver, rejecting unsupported backends.

### method id

```raku
method id() returns Str
```

Generate a 26-character migration identifier from the current millisecond timestamp and random UUID bits. Ancestry, rather than identifier order, determines execution order.

### method history

```raku
method history() returns Array
```

Return prepared versions in predecessor order under the history lock. Unfinished drafts are excluded; forks, gaps and invalid artifacts raise X::Red::Migration.

### method history

```raku
method history() returns Array
```

Build the single predecessor chain from prepared manifests. Call while holding the filesystem history lock.

### method entries

```raku
method entries() returns Array
```

Read version directories and validate manifest formats and identifiers. Includes drafts so callers can report or reject unfinished work.

### method prepare

```raku
method prepare(
    Str $name,
    Bool :$allow-destructive = Bool::False
) returns Mu
```

Generate SQL for every configured driver from the last prepared snapshot, or compile a named draft. Missing dialect history is backfilled first; destructive changes require allow-destructive.

### method create

```raku
method create(
    Str $name
) returns Mu
```

Create an offline draft containing frozen previous and target schemas plus migration.raku. Returns its directory without creating driver SQL or opening target databases.

### method prepare-draft

```raku
method prepare-draft(
    %draft,
    Bool :$allow-destructive = Bool::False
) returns Mu
```

Validate a draft predecessor and snapshots, compile its data declarations and publish all dialect artifacts atomically. Explicit driver overrides replace automatic SQL generation.

### method data-variant

```raku
method data-variant(
    IO::Path $directory,
    $before,
    $after,
    Str $source,
    Str $dialect,
    Bool :$allow-destructive = Bool::True
) returns Hash
```

Compile one dialect into ordered structural additions, data statements and final constraints. Generate the structural inverse and require explicit review of data reversibility.

### method prepare

```raku
method prepare(
    Str $name,
    Bool :$allow-destructive = Bool::False
) returns Mu
```

Prepare an ordinary structural version from configured models. An empty difference returns Nil; changes needing data preparation direct the caller to create a draft.

### method scripts

```raku
method scripts(
    @history,
    Str $dialect
) returns Array
```

Validate frozen source and schema fingerprints, then read each direction into ordered statements and file checkpoints for execution.

### method validate

```raku
method validate(
    @history,
    @rows,
    Bool :$allow-unresolved = Bool::False
) returns Mu
```

Compare database execution records with the prepared chain. Reject modified or missing executed versions, unresolved failures and gaps in applied history.

### method lock

```raku
method lock(
    $db,
    Str $dialect,
    Bool :$read-only = Bool::False
) returns Mu
```

Acquire the dialect-specific migration lock. SQLite opens a transaction; PostgreSQL and MySQL use database-scoped advisory or named locks.

### method unlock

```raku
method unlock(
    $db,
    Str $dialect
) returns Mu
```

Release native advisory or named migration locks. SQLite transaction completion is handled by the executor.

### method preflight

```raku
method preflight(
    $db,
    Str $dialect,
    %migration,
    @history,
    Bool $rollback
) returns Mu
```

Inspect the source and target snapshots before execution and reject unsafe alterations. NULL checks are deferred until their constraint statement so earlier data updates can run.

### method validate-alterations

```raku
method validate-alterations(
    $db,
    Str $dialect,
    $from,
    $to,
    Bool :$check-nulls = Bool::True,
    Str :$statement
) returns Mu
```

Check nullable tightening and metadata-sensitive changes against the actual database. An optional statement restricts checks to the ALTER TABLE currently being executed.

### method run

```raku
method run(
    Str $connection,
    Bool :$rollback = Bool::False,
    Bool :$inspect = Bool::False,
    Bool :$report = Bool::False,
    Str :$to
) returns Mu
```

Apply, revert or inspect a validated migration chain on a pinned connection. Maintain per-version and per-file checkpoints, with transactional behavior appropriate to the selected dialect.

### method apply

```raku
method apply(
    Str :$connection = "default",
    Str :$to
) returns Mu
```

Synchronously apply pending versions to the selected connection, optionally stopping at a target ID. Return the number applied; recorded versions are not executed again.

### method rollback

```raku
method rollback(
    Str :$connection = "default"
) returns Mu
```

Synchronously execute the latest non-reverted version in the down direction. Refuse unavailable inverses; structural rollback does not restore discarded data.

### method status

```raku
method status(
    Str :$connection = "default"
) returns Mu
```

Return migration identities, names and database execution states without creating history tables or changing application schemas.

### method status-report

```raku
method status-report(
    Str :$connection = "default"
) returns Hash
```

Return initialization, connection, model, migration and draft details for CLI reporting. This is an inspection operation and does not initialize migration history.

### method plan

```raku
method plan(
    Str :$connection = "default",
    Bool :$allow-destructive = Bool::True,
    Bool :$validation = Bool::False
) returns Array
```

Compare configured models with the live database and return supported SQL changes without executing them. This differs from prepare, which compares historical snapshots.

### method sync

```raku
method sync(
    Str :$connection = "default",
    Bool :$allow-destructive = Bool::False
) returns Mu
```

Apply the live development schema plan without advancing versioned history. Destructive changes require explicit opt-in; callers must not run inside an existing Red transaction.

### method test

```raku
method test(
    Str :$driver,
    :@command = Code.new,
    Bool :$keep = Bool::False,
    Callable :$fixtures,
    Str :$fixture-after,
    Bool :$compare-models = Bool::True
) returns Mu
```

Validate history in fresh disposable databases, including schema verification, reversible rollback and reapplication. Optional fixtures run after a selected prefix; a child command receives the isolated test connection. Pending inverse implementations fail validation.

### method logical

```raku
method logical(
    %migration
) returns Red::Migration::Snapshot
```

Load a version logical schema after checking its fingerprint. Portable history is required for automatic backfill and serialization.

### method generated

```raku
method generated(
    %migration,
    Str $driver
) returns Bool
```

Check whether both SQL directions still match their generated fingerprints. Custom SQL cannot be silently regenerated for another driver or predecessor.

### method data-source

```raku
method data-source(
    %migration
) returns Mu
```

Return a version frozen transformation source after validating its source and previous-schema checksums. Versions without data declarations return the undefined Str type.

### method variant

```raku
method variant(
    IO(Any) $directory,
    $before,
    $after,
    Str $driver,
    Bool :$manual = Bool::False,
    Str :$data
) returns Hash
```

Produce one driver schema and SQL directions from portable snapshots, data declarations or complete manual overrides. Record generated fingerprints and inverse availability.

### method backfill

```raku
method backfill(
    Str :$driver!
) returns Mu
```

Generate and validate a missing driver variant for every prepared historical version. Preserve version IDs and existing dialects, and publish only after the staged history passes validation.

### method verify

```raku
method verify(
    Str :$connection = "default"
) returns Mu
```

Compare the selected database with the last applied snapshot. Ignore migration bookkeeping tables and reject unexpected tables, column differences or missing indexes.

### method serialize

```raku
method serialize(
    Str :$after!,
    :@order = Code.new,
    :@check-connections = Code.new
) returns Mu
```

Rebase unpublished branches after a protected prefix in the requested tip order. Reject conflicts and custom SQL, regenerate rewritten versions with new IDs, and validate before atomic publication. Check every supplied deployment connection for already executed versions.

