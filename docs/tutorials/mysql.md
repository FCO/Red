# Working with MySQL

Install the separate [`Red::Driver::MySQL`](https://github.com/FCO/Red-Driver-MySQL)
distribution compatible with your Red version:

```sh
zef install Red::Driver::MySQL
```

Create the `red_example` database and a user with the required table privileges
before running the example. The driver uses DBIish and needs its native MySQL
client library. If DBIish cannot discover your installed client, set
`DBIISH_MYSQL_LIB` to its full library path (for example,
`/opt/homebrew/opt/mysql-client/lib/libmysqlclient.dylib` on Homebrew).
`database` is required; the default host is `localhost`, port is
3306 and user is `root`. Use a dedicated application account. An existing
`DBDish::mysql::Connection` can be supplied as `:dbh`.

DDL can cause implicit commits on MySQL. Consult the [migration workflow](../migrations.md)
before mixing schema and data changes, and the [regex matrix](../regex-support.md)
for engine/version limitations.

## Model example

Run this against a new database or file; `schema(...).create` creates tables.
Set `MYSQL_USER` and `MYSQL_PASSWORD` before running.

```raku
use Red:api<2>;

my $*RED-DB = database 'MySQL', :host('127.0.0.1'), :port(3306), :database('red_example'),
    :user(%*ENV<MYSQL_USER>), :password(%*ENV<MYSQL_PASSWORD>);

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

For an application default, pass the same arguments to `red-defaults 'MySQL', ...`.
For upgrades use [migrations](../migrations.md). See also [available drivers](../drivers.md).
