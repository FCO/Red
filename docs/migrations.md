# Versioned migrations

Configure the models, SQL dialects, target connections and artifact directory in
`red.rakuconf`. This file and schema snapshots are executable Raku configuration.
Run commands from the project root and keep migration files in version control.

```raku
use lib 'lib';
use Red;
use Red::Migration::Configuration;
use MyApp::User;
use MyApp::Post;

Red::Migration::Configuration.new(
    :models[MyApp::User, MyApp::Post],
    :drivers<SQLite Pg MySQL>,
    :directory('migrations'),
    :connections{
        default => { database 'SQLite', :database<development.sqlite> },
        production => {
            database 'Pg', :host<localhost>, :dbname<application>, :user<application>
        },
    },
)
```

Connections may be driver objects or lazy factories. Factories let `prepare`
load configuration without opening target databases. Install the separate
`Red::Driver::Pg` and `Red::Driver::MySQL` distributions for those dialects.
SQL generation delegates to driver translation methods without constructing
connections. The tested native versions are PostgreSQL 15 and MySQL 8.4.

## Commands

```text
raku -Ilib bin/red plan
raku -Ilib bin/red sync --dev
raku -Ilib bin/red prepare add-user-email
raku -Ilib bin/red status --connection=production
raku -Ilib bin/red apply --connection=production
raku -Ilib bin/red rollback --connection=production
```

All commands accept `--config=path/to/red.rakuconf`; connection commands default
to the configured `default` connection. `plan` prints DDL without applying it.
`sync` applies the development plan and requires `--dev`. These operations do not
advance migration history. Tables outside the configured models are not dropped
by development synchronization.

`prepare` compares models with the last **prepared snapshot**, not the live local
or production database. Initially it compares against an empty schema. An empty
diff produces no migration. Destructive preparation and development sync require
`--allow-destructive`; the generated SQL must still be reviewed before use.
Preparing an initial migration does not adopt an existing database automatically.

## Artifacts

```text
migrations/<sortable-id>-add-user-email/
  migration.rakuconf
  Pg/
    schema.rakuconf
    up.sql
    down.sql
  MySQL/...
  SQLite/...
```

IDs contain a 48-bit millisecond timestamp and 80 random bits encoded in 26 base32
characters. Ordering is determined by each manifest's explicit predecessor, not
by filenames. Parallel development histories must be resolved explicitly.
Preparation takes a filesystem lock and publishes a directory only after all
configured drivers generate successfully.

The manifest records format version 1, identity, predecessor, snapshot checksums
and reversibility per driver. Snapshots construct `Red::Cli::Table` and
`Red::Cli::Column` objects, preserving column order, automatic IDs, primary keys,
unique constraints, foreign keys, index SQL and CHECK/EXCLUDE SQL. They do not
import historical application models or serialize circular table references.
The Raku type name is stored as `raku-type`, separately from the SQL `type`.
Snapshots use deterministic serialization and SHA-1 integrity checksums.

`up.sql` changes the previous schema into the new one; `down.sql` does the inverse.
SQL can be edited before the migration is first applied, for example to populate
new columns before removing old ones. Snapshots describe the intended final
schema; custom SQL must produce that state. A structural down migration does
**not** restore removed data.

When an automatic inverse is unsupported, `down.sql` contains an explanatory
comment and the manifest marks that driver `reversible => False`. To supply a
manual inverse, edit down.sql and mark the driver reversible before first apply.
Otherwise rollback refuses to run. Once a migration has executed, both scripts
are immutable: even a reverted migration retains its recorded checksums.

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
