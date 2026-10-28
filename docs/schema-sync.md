# Schema synchronization

`schema(...).plan` compares selected models with the connected database and
returns an ordered `Array[Str]` of DDL statements without executing them.
`schema(...).update` validates the complete plan before executing any DDL.
Both methods accept `:where($driver)` and use it for introspection, type mapping
and execution. Tables outside the selected schema are never automatically dropped.

```raku
my $db = database 'SQLite', :database<development.sqlite>;
my $schema = schema(Product, Category);
.say for $schema.plan(:where($db));
$schema.update(:where($db));
```

Removing a plain column is visible in the plan but requires an explicit opt-in:

```raku
$schema.update(:where($db), :allow-destructive);
```

Indexed columns, referenced columns and constraint changes are rejected rather
than silently removing dependent objects. Renames are not inferred: changing a
model table name creates a new table and leaves the old, unmanaged table intact.
A new foreign key must reference an individually unique or single-column primary
key. Cycles between distinct new tables are unsupported; self references work.

## Capabilities

| Operation | SQLite | PostgreSQL 15 | MySQL 8.4 |
|---|---|---|---|
| Create table, serial ID, composite PK, simple/composite UNIQUE, single-column FK | Yes | Yes | Yes |
| Add nullable unconstrained column | Yes | Yes | Yes |
| Drop column without dependencies, with opt-in | 3.35+ | Yes | Yes |
| Widen VARCHAR on an unconstrained column | Explicit error | Yes | Yes |
| Change nullability on an unconstrained column | Explicit error | Yes | Yes |
| Rebuild existing tables or transform data | Not implemented | Not implemented | Not implemented |

NOT NULL changes are checked for existing NULL values before execution. MySQL
MODIFY preserves character set and collation and rejects columns with unmanaged
defaults, comments or EXTRA attributes. Other type conversions, existing
constraint changes and new non-null columns are explicit errors in this phase.
No SQLite table reconstruction is performed. Successful SQLite sync enables
foreign-key enforcement on that connection before opening its transaction.

PostgreSQL and SQLite updates use a transaction and roll back execution failures.
MySQL DDL can commit implicitly: a later failure can leave earlier DDL applied.
`X::Red::Schema::UpdateFailed` exposes `.sql`, `.completed-statements` and `.cause`;
completed statements describe execution, not a guarantee of committed changes.
Unsupported operations throw `X::Red::Schema::UnsupportedChange`; removals without
opt-in throw `X::Red::Schema::DestructiveChange`. A raw ChangeColumn AST is rejected
because it lacks the catalog validation required by this flow.

## CLI

The config file returns a `Red::Configuration` or uses its exported `config` DSL.
Set its `.schema` and `.driver`; `use Red::Configuration` imports that DSL.

```text
red prepare --config-file=red.rakuconfig
red sync --dev --config-file=red.rakuconfig
red sync --dev --allow-destructive --config-file=red.rakuconfig
```

`prepare` prints the plan. `sync` requires `--dev`; the destructive option is
separate. `migration-plan` uses the same validated planner. The configuration file
and its model modules are executable Raku and are loaded normally.

## Validation and MySQL integration

`t/89-schema-update.rakutest` and `t/90-schema-sync-preflight.rakutest` through
`t/95-schema-sync-limits.rakutest` cover idempotency, data preservation, explicit
connections, constraints, capability errors, CLI behavior and execution failures.
The native CI jobs run the shared driver/alter/limits scenarios on PostgreSQL 15
and MySQL 8.4; the main suite covers SQLite and CLI subprocesses.

The MySQL driver is a separate distribution. CI pins revision
`abe3a0ee01f62dc7f4da371c74a4a3bdddf77ddb` and applies
`tools/schema-sync-mysql.patch`, matching the companion driver worktree changes.
The patch preserves composite unique metadata and auto-increment information,
checks column dependencies, and gives each runner database a unique name. Keep
this patch until the corresponding driver changes are published, then pin that
revision and remove the patch application together.

This feature is development schema sync, without migration history, concurrent
migration coordination or inference of data transformations. Review the plan
before applying it and avoid concurrent schema writers during synchronization.
