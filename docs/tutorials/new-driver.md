# How to create a new driver

A driver connects Red's AST and model types to a database engine. Keep a new
backend in a separate distribution, `Red::Driver::YourDB`, with the module at
`lib/Red/Driver/YourDB.rakumod` and an entry in `META6.json`'s `provides` map.
Then `database 'YourDB', ...` loads it without changes to Red's loader.

Start with [Red::Driver](../api/Red/Driver.md),
[CommonSQL](../api/Red/Driver/CommonSQL.md),
[Statement](../api/Red/Statement.md) and the
[driver boundary](../architecture/driver-boundary.md). The bundled
[SQLite implementation](https://github.com/FCO/Red/blob/master/lib/Red/Driver/SQLite.rakumod)
is a complete example; the external [Pg](https://github.com/FCO/Red-Driver-Pg),
[MySQL](https://github.com/FCO/Red-Driver-MySQL) and
[DuckDB](https://github.com/FCO/Red-Driver-DuckDB) drivers illustrate other clients.

## Connection and statement contract

Compose `Red::Driver::CommonSQL` for shared SQL translation, or `Red::Driver` if
your backend needs its own translation layer. Accept typed connection parameters
and optionally a native `:dbh`. Define which component owns and closes each handle.

Implement these operations:

| Operation | Contract |
| --- | --- |
| `multi method prepare(Str $sql)` | Return a `Red::Statement` wrapping a native prepared statement. |
| `translate(Red::AST $ast, $context?)` | Return SQL/bind pairs, or a sequence of pairs for multiple statements. Preserve bind order. |
| `default-type-for(Red::Column $column --> Str:D)` | Select a physical type. CommonSQL delegates to `default-type-for-type`. |
| `type-by-name`, `inflate`, `deflate` | Map explicit SQL types and convert database/Raku values, including nulls. |
| `schema-reader` | Supply catalog inspection through `Red::SchemaReader`. |
| `map-exception` | Map native errors to typed `X::Red::Driver::Mapped::*` exceptions, retaining the cause. |

`Red::Driver.prepare(Red::AST)` optimizes/translates the AST, prepares SQL and
attaches deflated values as `.binds`. Your statement's `stt-exec($statement, *@bind)`
executes the native statement, using explicit binds when supplied and `@!binds`
otherwise, and returns the native handle used for subsequent reads.
`stt-row($statement)` returns a hash keyed by result column names and a false value
at exhaustion. Reuse the public `Red::Statement.execute` and `.row` wrappers so
exception mapping and transaction guards remain active. Implement cursor cleanup
through `finish-statement` when the client requires it.

## SQL lowering and types

Override CommonSQL's `multi method translate` candidates for syntax your engine
does not support. Quote identifiers with the driver's quoting methods; pass user
values as bind parameters. Test placeholder ordering in nested expressions,
subqueries and multi-statement operations. Never interpolate values into SQL.

Implement generated primary keys and `Red::AST::LastInsertedRow` together. Red's
`serial` means a non-null generated integer primary key, not a requirement that
the database have a type named SERIAL. Supply the physical type and generation
strategy. Test explicit IDs as well as generated IDs; implement `advance-sequences`
when explicit inserts require sequence synchronization.

Backend-only AST nodes belong in your distribution and can use
`Red::AST::DriverExtension`. Put backend schema helpers there too. Regex lowering
belongs in `Red::Driver::YourDB::Regex`; reject unsupported operations with
`X::Red::Compiler::Unsupported` rather than silently altering their meaning.

## Transactions, catalogs and capabilities

Implement `begin`, `commit`, `rollback` and savepoint operations on the intended
connection. The base `begin` uses `new-connection`; override it if your client must
retain a session (SQLite does). Test that a nested rollback preserves outer writes,
that closed scopes reject queries and that cursors are released before commit.

Catalog readers implement `tables-names`, `indexes-of`, `table-definition` and
`table-definition-from-create-table`. Index support also needs catalog normalization
and the relevant CommonSQL capability methods: for example,
`supports-partial-indexes`, `supports-index-method` and `supports-operator-classes`.
Do not advertise a capability merely because the server accepts related syntax.

Migration hooks are defined in [Red::Driver::Migrations](../api/Red/Driver/Migrations.md).
Implement locking, session management, DDL transaction behavior, automatic columns,
column alterations and temporary database provisioning as appropriate. The base
role rejects unsupported operations. Implement `database-client` if the CLI can
launch your native client. Global notifications have a separate optional
[events contract](../api/Red/Driver/Events.md).

## Validate and distribute

Add tests in your driver's distribution for loading by name, connection failures,
CRUD, binds, nulls, types, generated IDs, relationships, indexes/catalogs,
transactions/savepoints and supported migrations. Use temporary databases and
explicit assertions for unsupported features. Exercise the actual native client;
translation-only tests cannot establish database behavior.

During development, prepend both libraries when running integration tests:

```sh
raku -Ilib -I../Red-Driver-YourDB/lib ../Red-Driver-YourDB/t/driver-support.rakutest
raku -Ilib -c ../Red-Driver-YourDB/lib/Red/Driver/YourDB.rakumod
prove6 -lj8 t
```

The first command is an example path for a test you provide. Set `RED_DATABASE`
when running Red tests against your backend, using a disposable database. Declare
Red and client dependencies in `META6.json`, document native installation and
supported server versions, and verify the compatible core/driver revisions before
publishing. Keep public API documentation as Pod6 in source; regenerate it with
`raku -Ilib tools/make-docs.raku` in the Red checkout.
