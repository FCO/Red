# Versioned migrations

Configure the models, SQL dialects, target connections and artifact directory in
`red.rakuconf`. This file and schema snapshots are executable Raku configuration.
Run commands from the project root and keep migration files in version control.

Generated migration artifacts also use `config { ... }`. `migration.rakuconf`
contains manifest assignments, `operations.rakuconf` contains the logical changes,
and every `schema.rakuconf` uses `table({ ... })` and `column({ ... })` builders
to reconstruct `Red::Cli::Table` and `Red::Cli::Column` objects. This applies to
both the portable schema and each driver's schema. Fields and nested metadata
are written on separate indented lines in a deterministic order.

Older artifacts using constructor expressions and raw Raku collections remain
readable. Do not reformat an applied migration: schema checksums protect its
recorded contents. New preparations and generated backfill/serialization artifacts
use the new format automatically.

Open an interactive SQL client using a configured connection:

```sh
red connect
red connect --connection=production
red connect --config=other.rakuconf --connection=default
```

The command starts `psql`, `mysql` or `sqlite3` with the selected connection's
settings and passes through its exit status. Install the corresponding client
locally; the workshop development image includes all three. Passwords are passed
through the child environment rather than command arguments. Lazy connection
factories are supported. Connections supplied only as existing database handles
must also retain their connection parameters for the external client.
SQLite in-memory databases and URI filenames cannot be opened this way.
`RED_MIGRATION_TEST` selects the temporary test database when set, including
inside a command launched by `red migration apply --test`.

```raku
use lib 'lib';
use Red;
use Red::Migration::Configuration;
use MyApp::User;
use MyApp::Post;

config {
    .models = [MyApp::User, MyApp::Post];
    .drivers = <SQLite Pg MySQL>;
    .directory = 'migrations';
    .connections = %(
        default => { database 'SQLite', :database<development.sqlite> },
        production => {
            database 'Pg', :host<localhost>, :dbname<application>, :user<application>
        },
    );
}
```

Connections may be driver objects or lazy factories. Factories let `prepare`
load configuration without opening target databases. Install the separate
`Red::Driver::Pg` and `Red::Driver::MySQL` distributions for those dialects.
SQL generation delegates to driver translation methods without constructing
connections. The tested native versions are PostgreSQL 15 and MySQL 8.4.

`config { ... }` uses the `Configuration` module's typed builder and returns a
`Red::Migration::Configuration` object. The module also exports Configuration's
`single-config-run`, `config-run`, `get-config` and `set-config` functions. Application
code can use `Red` directly: queries use `.connections<default>` automatically,
and `schema()` includes the configured `.models`. Tests can replace these defaults
with `set-config -> { config { ... } }`, without writing temporary configuration files.

```raku
use lib 'lib';
use Red:api<2>;
use MyApp::Task;

say schema().models.keys;
MyApp::Task.^create(:title<Example>);
```

Run from the directory containing `red.rakuconf`. The file is loaded on first use,
not when `Red` is imported. Loading `schema()` resolves models without opening a
database. Connection factories run on the first database operation and their
results are reused per thread until the Configuration reader is replaced, for
example by `set-config`. Restart the application to pick up file edits.

An explicit `$*RED-DB` takes precedence, followed by `red-defaults`, followed by
`.connections<default>`. The `.drivers` list selects migration SQL dialects;
it does not select an application connection. Other configured connections remain
explicit choices, including `red migration apply --connection=production`.
`schema(ModelA, ModelB)` and schemas with aliases still use exactly the supplied models.
Without configuration, `schema()` is empty and queries still require an explicit
connection. Invalid configuration and missing default connections produce errors.

For example, a test can install a connection before invoking application code:

```raku
set-config -> {
    config {
        .drivers = ['SQLite'];
        .models = ['MyApp::Task'];
        .connections = %(default => { database 'SQLite' });
    }
}
MyApp::Task.^create(:title<Isolated>); # Uses the test override automatically.
```

## Commands

```text
raku -Ilib bin/red migration plan
raku -Ilib bin/red migration sync --dev
raku -Ilib bin/red migration prepare add-user-email
raku -Ilib bin/red migration status --connection=production
raku -Ilib bin/red migration apply --connection=production
raku -Ilib bin/red migration rollback --connection=production
```

All commands accept `--config=path/to/red.rakuconf`; connection commands default
to the configured `default` connection. `plan` prints DDL without applying it.
`sync` applies the development plan and requires `--dev`. These operations do not
advance migration history. Tables outside the configured models are not dropped
by development synchronization.

Migration commands live under `red migration`: `plan`, `sync`, `create`, `prepare`, `apply`,
`rollback`, `status`, `init-tests`, `backfill` and `serialize`. The former top-level
spellings are no longer accepted. The older model-based planner is available as
`red migration plan --model=... --driver=...`; the legacy database bootstrap command
is `red migration prepare-database`.

`red migration status` reports `Database migrations: Not initialized` when the
selected database has no migration history table. It also lists configured models,
their SQL table names and table presence, column names, Raku types, nullability and
key information, followed by prepared versions and their states. Preparing files
does not initialize database history. Status does not create tracking or model tables.
If the configuration file is absent, status reports that explicitly and lists no
configured models; connection failures remain errors.

For example, before applying the tutorial's first version:

```text
Database migrations: Not initialized
Configuration: /project/red.rakuconf
Connection: default (Pg)
Migration directory: /project/migrations
Configured models: 1
  Task -> task (table missing)
    id: Int [required, primary key, automatic]
    title: Str [required]
Prepared migrations: 1
Recorded migrations: 0
  <id> pending initial
```

`prepare` compares models with the last **prepared snapshot**, not the live local
or production database. Initially it compares against an empty schema. An empty
diff produces no migration. Destructive preparation and development sync require
`--allow-destructive`; the generated SQL must still be reviewed before use.
Preparing an initial migration does not adopt an existing database automatically.

## Artifacts

```text
migrations/<sortable-id>-add-user-email/
  migration.rakuconf
  schema.rakuconf
  operations.rakuconf
  Pg/
    schema.rakuconf
    up/001-schema.sql
    down/001-schema.sql
  MySQL/...
  SQLite/...
```

IDs contain a 48-bit millisecond timestamp and 80 random bits encoded in 26 base32
characters. Ordering is determined by each manifest's explicit predecessor, not
by filenames. Parallel development histories must be resolved explicitly.
Preparation takes a filesystem lock and publishes a directory only after all
configured drivers generate successfully.

New manifests use format version 2 and record identity, predecessor, snapshot checksums
and reversibility per driver. Snapshots construct `Red::Cli::Table` and
`Red::Cli::Column` objects, preserving column order, automatic IDs, primary keys,
unique constraints, foreign keys, index SQL and CHECK/EXCLUDE SQL. They do not
import historical application models or serialize circular table references.
The Raku type name is stored as `raku-type`, separately from the SQL `type`.
Snapshots use deterministic serialization and SHA-1 integrity checksums.

`up/` changes the previous schema into the new one; `down/` does the inverse.
SQL can be edited before the migration is first applied, for example to populate
new columns before removing old ones. Snapshots describe the intended final
schema; custom SQL must produce that state. A structural down migration does
**not** restore removed data.

When an automatic inverse is unsupported, `down/001-schema.sql` contains an explanatory
comment and the manifest marks that driver `reversible => False, down-state => 'pending'`. To supply a
manual inverse, edit its down scripts and mark the driver reversible with `down-state => 'available'` before first apply.
Otherwise rollback refuses to run. Once a migration has executed, both scripts
are immutable: even a reverted migration retains its recorded checksums.

## Synchronous data migrations

Use `prepare NAME` directly for supported structural changes. Required additions
to existing tables and nullable-to-required changes need an explicit data draft:

```sh
red migration create require-description
```

Creation is offline. The version directory contains `migration.rakuconf`, the
previous snapshot `before.rakuconf`, the final `schema.rakuconf`, and
`migration.raku`. It does not contain driver SQL yet. Status lists unfinished
drafts; application and CI refuse them until prepared. Explicit drafts also allow
data-only migrations when the schema has not changed.

Write ordinary Red expressions against the historical models supplied by the
compiler. Do not import the application's current model implementation:

```raku
Task.^migration: {
    $_ = 'No description' without .description;
};

Status.^populate: {
    .^create: :name<pending>;
    .^create: :name<completed>;
};
```

`without` preserves defined values, including empty strings. The equivalent
model-topic form is `.description = 'No description' unless .description.defined`.
An assignment without a condition updates every row; there is no implicit NULL
filter. Arithmetic, comparisons, concatenation and supported Red column methods
are translated into SQL. `if`, `unless`, `with` and `without` modifiers are
supported; their block forms currently require a single assignment and no else.
Conditions require Boolean comparisons or defined checks. Unsupported syntax,
loops, arbitrary calls and external effects fail explicitly. There is no per-row
Raku execution or fallback. The compiler requires a Raku runtime with `.AST` support;
users do not need `CHECK red-compile` or a frontend environment flag.

`.^populate` blocks compile explicit named `.^create` calls into INSERT statements.
The existing no-argument application
`.^populate` method remains unchanged and is never invoked by this compiler.
These inserts are versioned production data; test-only records belong in fixtures.

```sh
red migration prepare require-description
```

Prepare accepts a unique draft name, ID or directory basename. It verifies that
the predecessor and frozen snapshots still match and publishes all configured
drivers atomically. Data blocks retain source order. SQL files are ordered as:

```text
Pg/up/001-structure.sql
Pg/up/002-data.sql
Pg/up/003-constraints.sql
Pg/down/001-schema.sql
```

Empty groups are omitted and numbering remains contiguous. Structural additions
come first; existing columns are retained while transformations run. New required
columns are initially added nullable. Updates and inserts follow in source order;
final constraints and removals run afterward. NULL validation occurs immediately
before the relevant NOT NULL statement, after any earlier UPDATE has run.
There are no phase directories, background jobs, batching, daemon, polling,
automatic application processing, manual stage confirmations or `apply --wait`.

```sh
red migration apply
```

Apply runs the entire ordered SQL sequence synchronously. PostgreSQL can execute
it in one transaction; MySQL DDL can commit implicitly. Large updates can block
application writes. Coordinate the application deployment and its writers; this
does not implement an online expand/contract protocol.

The historical source has a checksum, as do both snapshots and the executed SQL.
Backfill and serialization recompile the frozen source instead of reading current
application models. Do not modify executed versions. Drafts without data preserve
the ordinary SQL-only flow. The experimental format-3 job artifacts are rejected;
no existing database or auxiliary job table is automatically deleted or converted.

Transformations do not have an inferred data inverse. Prepare writes the structural
down statements it can generate and marks that driver's down implementation pending.
Before CI, review/provide down SQL and set its manifest `down-state` to `available`
with `reversible => True`, or explicitly choose `irreversible` with a reason and
`reversible => False`. A structural inverse does not restore overwritten data.
Validation tests irreversible barriers and earlier reversible prefixes separately.

Type conversions that require data transformation are not generated automatically.
Only the planner's safe supported changes, such as native VARCHAR widening, remain
automatic. SQLite column tightening still requires explicit table reconstruction.
For these cases, supply complete `DRIVER/up/` and `DRIVER/down/` SQL inside the draft
and an explicit `DRIVER/overrides.rakuconf` before prepare:

```raku
use Red::Migration::Artifact 'overrides';
config {
    .manual = True;
    .down-state = 'available';
    .reason = 'Explicit SQL and its inverse have been reviewed';
}
```

The override replaces SQL generation for that driver. Its final snapshot is
generated from the frozen target unless supplied explicitly. Review and test that
the SQL produces that schema. Custom SQL is not automatically translated to new
drivers or rebased during serialization.

## Database history and concurrency

The internal Red model `Red::Migration::Applied` stores records in
`red_migrations`: migration ID, predecessor, up/down checksums, state, direction,
application/reversion timestamps and completed statement count. `apply` runs only
pending migrations. `rollback` runs only the last applied migration's down script.
`status` reports pending, applied, reverted, running or failed state. Missing
historical files, changed executed scripts, invalid ancestry and gaps are errors.

SQLite holds a write transaction for the operation, with foreign keys enabled.
PostgreSQL pins one physical session, holds an advisory lock, and uses a
transaction per migration. MySQL holds a named lock scoped to the database;
DDL may commit implicitly. It records running/failed state and completed
statements durably. A failed or interrupted MySQL migration blocks further
application and rollback until the schema and history are manually reconciled;
there is no automatic retry or assumption that previous DDL rolled back.

A reported completed statement count describes execution, not a guarantee that
all those statements were committed. The executor finishes result cursors before
committing or releasing sessions. Run migrations outside an existing Red
transaction.

## Automatic generation boundaries

Supported operations include table creation/removal, nullable unconstrained
column additions/removals, native indexes and supported initial constraints.
New tables are created in foreign-key order; distinct-table cycles are rejected.
Foreign keys must target an individually unique column or single-column primary
key. Self references work.

PostgreSQL/MySQL support VARCHAR widening and nullability changes on ordinary,
unindexed columns. Narrowing is not an automatic inverse. Before tightening
nullability, apply checks for NULL values. MySQL also rejects changes that would
lose unmanaged defaults, comments, EXTRA attributes or a non-default collation.

SQLite reconstruction, column/table rename inference, general type conversions,
changes to existing constraints, automatic data transformations and column
SQL defaults require explicit migrations. A model with a SQL default is rejected
rather than silently generating a table without it. Preparing unsupported changes
raises `X::Red::Migration` before publishing a migration directory.

SQL scripts support multiple statements, multiline SQL, quoted semicolons,
doubled quote escapes, nested block comments and PostgreSQL dollar quotes.
Stored programs/triggers, executable MySQL comments, ambiguous backslash string
escapes, transaction commands and client directives are rejected before execution.
There is no automatic coordination of application deployments or zero-downtime
transition code.

## Multiple files and older histories

Each direction is an independently ordered directory of SQL files, for example
`up/001-schema.sql`, `up/002-populate.sql`, and `down/001-revert.sql`. Filenames
must begin with at least three digits followed by a hyphen and a name containing
letters, digits, hyphens or underscores. Duplicate numeric prefixes are errors.
Adding, removing, renaming or editing any file changes the direction checksum.
Version 1 histories using `up.sql` and `down.sql` remain readable with their original
checksums; mixing a flat script and a directory for the same direction is rejected.

`red_migration_files` records each file's checksum, state and completed statement
count, alongside the migration record. Execution errors identify the file and
statement. Both history tables are reserved for Red.

## Validate before deployment

```text
raku -Ilib bin/red migration init-tests
raku -Ilib bin/red migration apply --test
raku -Ilib bin/red migration apply --test --driver=Pg -- raku -Ilib t/application.rakutest
raku -Ilib bin/red migration apply --test --driver=SQLite --keep
```

`init-tests` creates `t/migrations.rakutest` using
`Red::Migration::Test.migration-ok`, refusing to replace an existing test.
Include this test in project CI. Forked ancestry, pending down implementations,
SQL failures, schema differences and failed child commands fail validation.

Validation provisions a unique empty database for each configured driver, applies
the history, compares tables, columns, constraints supported by schema readers and
index presence, and compares against current models. It exercises reversible down
scripts and reapplies the history. An explicitly irreversible version forms a
rollback barrier; earlier reversible versions are tested against separate prefixes.
Index expressions and CHECK/EXCLUDE expression equivalence are not fully verified
by every schema reader. Application tests should exercise those constraints.

Inside the config block, configure administrative credentials for temporary native databases:

```raku
.test-servers = %(
    Pg => { host => 'localhost', user => 'postgres', password => %*ENV<PGPASSWORD> },
    MySQL => { host => 'localhost', user => 'root', password => %*ENV<MYSQL_PASSWORD> },
);
```

These accounts need CREATE/DROP DATABASE privileges. SQLite needs no test server.
Temporary databases are removed on success and failure. `--keep` retains the test
database and prints the private connection-context file path. A child command
requires one driver and receives `RED_MIGRATION_TEST` and `RED_DATABASE`.
Applications can use `Red::Migration::Environment.test-database()` to obtain that
connection. Migration managers in that child process also use the temporary context;
normal application connections must explicitly opt into the helper.

For upgrades with existing data, call the manager API:

```raku
$manager.test(:driver<Pg>, :fixture-after($initial-id),
    :fixtures(-> $db, $manager { $db.execute("INSERT INTO users(name) VALUES ('old')") }),
    :command<raku -Ilib t/application.rakutest>);
```

The callback runs after the selected prefix, before the remaining upgrades.

## Add a database dialect

Add the driver to `:drivers` and configure its test server, then run:

```text
raku -Ilib bin/red migration backfill --driver=MySQL
```

Every historical version receives its own up/down scripts and concrete snapshot.
Existing IDs and other drivers' artifacts remain unchanged. `prepare` automatically
performs missing backfills before preparing a new model change. When only a driver
was added, it creates no extra migration. Generation and validation happen in a
staging history; failures leave the published history unchanged.

Logical snapshots preserve Raku type names, SQL type origin, frozen mappings for
existing drivers and portable index/constraint descriptors. They do not load old
application models. For explicit SQL types, supply mappings inside the config block:

```raku
.type-mappings = %(MySQL => { 'users.code' => 'varchar(40)' });
```

Legacy histories without logical metadata require manual conversion before backfill.
Custom SQL is never silently translated. Supply the new driver's scripts and
`schema.rakuconf` in that version's driver directory, plus `overrides.rakuconf`:

```raku
use Red::Migration::Artifact 'overrides';
config {
    .manual = True;
    .down-state = 'available';
}
```

Use `down-state => 'irreversible'` and a reason only when intentionally irreversible.
Without a manual override, unsupported inverse generation remains `pending` and
fails validation. Review generated scripts and snapshots before deployment.

## Resolve parallel migrations

```text
raku -Ilib bin/red migration serialize --after=SHARED_ID --order=FIRST_TIP,SECOND_TIP \
    --check-connection=production
```

`--after` protects a shared linear prefix. `--order` names every branch tip in the
desired order; internal ancestry is preserved, including tails of different lengths
and different parents. The default tip order is lexical. Portable operations are
rebased onto the accumulated logical schema. Conflicting changes and custom SQL
require manual resolution. Ordinary apply/test refuses unresolved forks.

Unchanged versions keep their IDs. Rewritten versions receive new IDs and record
`replaces`; their SQL is regenerated and tested. Connections named by repeated
`--check-connection` options are checked for executed rewritten versions. Include all
shared deployment databases; filesystem history alone cannot discover deployments.
Never rewrite deployed migrations. Publication uses a stable filesystem lock and a
recovery journal so interrupted directory replacement can be recovered on next use.

## Hands-on workshop

For a script-driven example, an editable Docker development environment, independent
PostgreSQL development/production databases, and a complete deployment exercise,
follow [the migration workshop](../examples/migrations/README.md). Its CI executes
the commands from the document, including rollback and parallel-branch integration.
