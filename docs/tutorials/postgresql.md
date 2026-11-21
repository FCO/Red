# Working with PostgreSQL

PostgreSQL support is provided by the separate
[`Red::Driver::Pg`](https://github.com/FCO/Red-Driver-Pg) distribution, using `DB::Pg`.
Install PostgreSQL's native `libpq` client library and make it available to Raku,
then install the driver (including when upgrading from a Red with bundled Pg):

```sh
zef install Red
zef install Red::Driver::Pg
createdb red_example
```

`createdb` requires a running PostgreSQL server and an account permitted to create
databases. Red creates tables inside an existing database; it does not create that
database during normal model use.

## Connect and use models

Set `PGUSER` and `PGPASSWORD` for the example, then save and run this Raku program
against an empty `red_example` database:

```raku
use Red:api<2>;

my $*RED-DB = database 'Pg',
    :host('127.0.0.1'), :port(5432), :dbname('red_example'),
    :user(%*ENV<PGUSER>), :password(%*ENV<PGPASSWORD>);

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

The driver uses **`dbname`**, whereas SQLite and MySQL use `database`.
Its constructor accepts `host`, `port`, `dbname`, `user`, `password`, or an existing
`DB::Pg` object as `:dbh`. Omitted connection values use the driver's and libpq's
defaults. Keep credentials out of source files.

For an application default, use `red-defaults 'Pg', :dbname('red_example'), ...`
with the same named connection arguments instead of assigning `$*RED-DB`.

## Transactions and PostgreSQL features

Use `red-do { ... }, :transaction`; nested scopes use savepoints. See the
[transaction examples](../../README.md#transactions-and-savepoints) for manual guards.

PostgreSQL-specific range helpers and exclusion declarations require an explicit
`use Red::Driver::Pg::Schema;` after `use Red:api<2>;`. See
[ranges and exclusion constraints](../../README.md#postgresql-ranges-regex-and-exclusion-constraints),
[regex support](../regex-support.md), and the
[global events cookbook](cookbook.md#global-events-across-nodes).

Use the [migration workflow](../migrations.md) for schema upgrades, rather than
calling `schema(...).create` on existing tables. Backend-specific functionality
requires a driver release compatible with the Red core in use.

Red's test configuration accepts, for example:

```sh
RED_DATABASE='Pg host=127.0.0.1 port=5432 dbname=red_test user=red_test' prove6 -lv t/035-create.rakutest
```

Use a disposable database for tests. If the driver fails to load, check its install,
`libpq` availability and the cause attached to `X::Red::Driver::NotInstalled`.
See also [available drivers](../drivers.md).
