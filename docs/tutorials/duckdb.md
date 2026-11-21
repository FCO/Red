# Working with DuckDB

Install the separate [`Red::Driver::DuckDB`](https://github.com/FCO/Red-Driver-DuckDB)
distribution compatible with your Red version:

```sh
zef install Red::Driver::DuckDB
```

DuckDB is embedded and needs no server. Omit `:database` for an isolated in-memory
database. The driver uses `DB::DuckDB` and a native DuckDB library; follow the
[driver installation instructions](https://github.com/FCO/Red-Driver-DuckDB#installation)
for platform-specific dependencies and any required companion Red changes.

An existing `DB::DuckDB` object can be passed as `:dbh`. The driver opens a connection
on that database; `.close` closes the driver connection while the caller retains
ownership of the shared database handle.

The driver also provides file readers such as `read-csv` and `read-parquet` that
return Red models. See the [driver guide](https://github.com/FCO/Red-Driver-DuckDB#reading-files-as-models)
for temporary views, materialization and their lifetimes.

## Model example

Run this against a new database or file; `schema(...).create` creates tables.

```raku
use Red:api<2>;

my $*RED-DB = database 'DuckDB', :database('tasks.duckdb');

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

For an application default, pass the same arguments to `red-defaults 'DuckDB', ...`.
For upgrades use [migrations](../migrations.md). See also [available drivers](../drivers.md).
