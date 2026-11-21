# Working with SQLite

SQLite support ships with Red and uses DBIish and the native SQLite library.
Install Red with `zef install Red`. No database server is needed; the process must
be able to load SQLite's native library and write the database's directory.

## A persistent database

Save this as `sqlite-example.raku` and run `raku sqlite-example.raku`:

```raku
use Red:api<2>;

my $*RED-DB = database 'SQLite', :database('tasks.sqlite3');

model Task {
    has Int $.id is serial;
    has Str $.title is column is rw;
}

schema(Task).create;
my $task = Task.^create(:title<First>);
$task.title = 'Updated';
$task.^save;
say Task.^all.grep(*.title eq 'Updated').map(*.title).List;
```

Run this example against a new file: `schema(...).create` creates tables and is not
an upgrade mechanism. The file persists after exit. For an application-wide default,
use `red-defaults 'SQLite', :database('tasks.sqlite3')` instead of `$*RED-DB`.

## An in-memory database

`database 'SQLite'` defaults to `:database(':memory:')`. Each new connection has its
own database, which disappears when the connection closes. Retain the same driver
instance across schema creation and queries. This is convenient for isolated tests.

An existing `DBDish::SQLite::Connection` can be supplied with
`database 'SQLite', :dbh($connection)`. The native handle bypasses Red's transaction
guards when used directly.

## Transactions and backend features

Use `red-do { ... }, :transaction` to group writes. SQLite begins a transaction on
the existing connection; nested Red transactions use savepoints. Keep transactions
short when multiple processes write to the same database.

The driver supports catalog inspection and partial indexes. Regex translation is
experimental and disabled by default; opt in with
`database 'SQLite', :use-experimental-regex`. See the
[regex support matrix](../regex-support.md) for supported operations.

For versioned schema changes use the [migration workflow](../migrations.md).
SQLite changes that require rebuilding a table need manual migration SQL.

To select SQLite in Red's test configuration:

```sh
RED_DATABASE='SQLite' prove6 -lv t/002-sqlite.rakutest
```

See also [available drivers](../drivers.md) and the [SQLite API](../api/Red/Driver/SQLite.md).
