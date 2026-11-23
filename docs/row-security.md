# Row security

Red can restrict structured queries and writes with public model methods. Policies
can be declared locally, inherited, or supplied by roles. Normal Raku dispatch
chooses the effective method: a model override replaces a role method, and role
conflicts must be resolved explicitly.

```raku
use Red:api<2>;

role TenantPermissions {
    method SELECT-ALLOWED-IF(%context) {
        self.tenant-id == %context<tenant-id>
    }
    method INSERT-ALLOWED-IF(%context) {
        self.tenant-id == %context<tenant-id>
    }
    method UPDATE-ALLOWED-IF($new, %context) {
        self.tenant-id == %context<tenant-id>
            && $new.tenant-id == self.tenant-id
    }
    method DELETE-ALLOWED-IF(%context) {
        self.tenant-id == %context<tenant-id>
    }
}

model Document does TenantPermissions {
    has Int $.id is serial;
    has Int $.tenant-id is rw is column;
    has Str $.title is rw is column;
}

red-do :context{ :tenant-id(42), :user-id(7) }, {
    Document.^all.grep(*.title eq 'Report').List;
};
```

`self` represents the existing database row for SELECT, UPDATE, and DELETE, and
the candidate for INSERT. `$new` represents the proposed row for UPDATE. These
methods describe SQL expressions; they must be pure. Columns, context slots,
comparisons, numeric/string comparison casts, and boolean combinations are
supported. Arithmetic, computed columns, relationships, subqueries, database
calls, and column mutations inside a policy are rejected. A policy must produce
a boolean expression. Compilation has a bounded number of boolean decisions.
SQL NULL does not authorize a row.

Operations without a policy hook are allowed. Each hook restricts only its own
operation. For example, `method SELECT-ALLOWED-IF(|) { False }` blocks all SELECT
rows while leaving INSERT, UPDATE, and DELETE allowed.

## Context and lifetime

The application must authenticate users and supply a trustworthy context. Red
copies defined `Str`, `Bool`, `Int`, `Rat`, and `Num` values into an immutable
snapshot. Other objects and undefined values are rejected. An absent context is
an empty snapshot; policies that do not read context work without one. Reading a
missing policy context key raises `X::Red::RowSecurity`. Context values are SQL
parameters, including readonly numeric values.

All `red-do` variants accept `:%context`, including named connections, multiple
blocks, async execution, and transactions. Nested blocks inherit the context
when the argument is omitted. An explicit context replaces the entire parent
context, and leaving the block restores it. Async blocks capture their context
before scheduling.

When there is no active `red-do` context, Red uses the dynamic variable
`%*RED-CONTEXT` as the default. This also works without calling `red-do`, with
the database connection already configured:

```raku
{
    my %*RED-CONTEXT = :tenant-id(42), :user-id(7);
    Document.^all.List;
}
```

A `red-do` call without `:%context` captures the effective context at entry,
including this default. An explicit `:%context` takes precedence and replaces
it completely; `:context{}` does not inherit missing keys from the default.
Changing the default hash during a `red-do` block does not change that block's
snapshot. Outside `red-do`, new queries capture the current dynamic values;
changing those values invalidates queries or instances captured under a different
context. The same immutable scalar validation applies to both forms.

Bind the dynamic hash within each request or worker. `red-do :async` captures it
before asynchronous work is scheduled.

Lazy ResultSeq queries capture their creation context. Evaluation and cursor
reads require an equivalent context, including value types. Loaded instances
cannot be persisted under another context. Obtain a new query or reload an
instance in the context where it will be used. Context checks also apply to
prepared statements. Shared SQL plans and result caches are bypassed for
protected queries; unprotected queries retain their cache behavior.

## Enforcement and migration

SQLite filters each table source before joins and aggregation, preserving the
NULL-extended side of outer joins. Its protected writes validate the complete
candidate operation and execute on the same transaction connection. A denied
row in a batch rejects the whole mutation. Triggered writes, cascading foreign
keys, virtual or nonpersistent write targets, and policies that depend on
server-generated insert values are rejected. Cross-table and subquery write
predicates are not supported.

Live ResultSeq supplies capture the query's immutable context. Each subscriber
filters both its snapshot and future insert events through secured SQL under that
context; rows are not shared across subscriber contexts. Producer threads may use
a different context. Query callbacks run under the subscriber context. Protected
live sources require primary-key identity. As with ordinary live supplies,
updates and deletes do not emit new values.

Driver support is explicit. A driver or wrapper without the required row
security capabilities raises an error. Matching PostgreSQL, MySQL, and DuckDB
driver updates are required; older driver packages cannot silently fall back.
MySQL requires InnoDB and REPEATABLE READ or SERIALIZABLE for protected writes.
If DBIish cannot discover the installed native client, set `DBIISH_MYSQL_LIB` to
the full path of `libmysqlclient` before starting Raku.
DuckDB retains its external-source and compound-column write restrictions and
uses transaction rollback when savepoints are unavailable.

Snapshots record a portable representation of all four policies, with context
slots rather than caller values. Policy changes therefore participate in schema
diffs. Capture and apply migrations explicitly through the migration planner;
ordinary query execution never creates or changes policies. Explicit table creation
through `.^create-table`, `schema(...).create`, the driver schema API, or a
model-backed CREATE TABLE AST also installs PostgreSQL policies atomically with
the table. Existing tables and changed hooks still require an explicit migration.

PostgreSQL table creation and migrations generate ENABLE and FORCE ROW LEVEL SECURITY plus USING
and WITH CHECK policies. Policy names include a policy version. Migration DDL
also records fingerprints of the native definitions so altered or missing
policies can be rejected at execution. Use a separate administrative connection
for schema creation and migrations. Application roles must have neither superuser nor
BYPASSRLS. Red transports context with transaction-local configuration on the
actual execution connection. Reads outside an explicit transaction own a short
transaction and materialize their cursor before releasing that connection.
Old/new comparisons that PostgreSQL cannot represent in one row scope are
validated atomically by Red in addition to the native policy.

## SQL escape and trust boundary

Textual SQL remains an explicit escape. The fallback does not rewrite SQL
strings, inspect arbitrary views/functions, or restrict direct database access.
Use a separate administrative connection. PostgreSQL's native RLS still applies
according to that connection's role and transaction-local settings. This is an
ORM enforcement boundary, not a replacement for database privileges.

When updating a checkout with existing Rakudo caches, a `Stash ... not a mixin
type` deserialization error can require regenerating both `lib/.precomp` and
`t/lib/.precomp`. It is not an indication that SQLite is missing.
