# Red CLI

Red CLI is a tool to give easy access to some of Red features. Currently it has this experimental features:

- list-tables

  list tables on a given db connection
  
```
$ red list-tables --driver=SQLite --database=example.db     
post
sqlite_sequence
person
```

- print-stub

  prints a stub code to use the given database
  
```
$ red print-stub --driver=SQLite --schema-class=Blog --database=example.db
use Red:api<2>;
use Blog;

red-defaults "SQLite", :database("example.db");

.say for Post.^all;
.say for SqliteSequence.^all;
.say for Person.^all;
```

- prepare-database

Receives database connection and a list of models and create those on that database. If passed the option `--populate` calls the `.^populate` metamethod on those models.

```
$ raku -I../Red ../Red/bin/red prepare-database --models=Ad --populate --driver=SQLite
```

- migration-plan - WiP
- generate-code - WiP

## Named fixtures

Store named database snapshots in a configurable directory:

```raku
use Red;
use Red::Migration::Configuration;

config {
    .models = [User, Post];
    .connections = %(default => { database 'SQLite', :database<app.sqlite> });
    .fixtures-directory = 'fixtures'; # default
}
```

The models must be imported before this configuration. Relative fixture paths start
at the directory containing `red.rakuconf`.

```sh
red fixture save demo
red fixture list
red fixture apply demo
red fixture save demo --force
red fixture apply demo --config=config/development.rakuconf
```

`save` exports every row of the configured models into `fixtures/demo.raku`,
preserving IDs, NULLs and stored column values. It orders rows by foreign keys,
including references within one model. Missing referenced rows and cycles that
prevent insertion fail without publishing a partial fixture. An existing fixture
requires `--force` to replace it.

`list` prints valid fixture names alphabetically, without extensions. It does not
open the database or execute fixtures; a missing directory produces an empty list.
Names contain only ASCII letters, digits, underscores and hyphens.

`apply` executes the named Raku script in a transaction using Red's normal connection
resolution. Existing tables and the same configured model names are required;
model order may change. Conflicts and exceptions roll back all inserted rows.
Reapplying executes the script again; Red keeps no fixture history and performs no
automatic updates or migrations. In a migration test environment, commands use the
disposable test database.

Generated scripts call `Model.^populate(:rows([...]), :deflated)` through the
configured model types. `:deflated` hydrates stored values with the model's column
inflators before insertion. Handwritten trusted scripts may import models and call
`User.^populate` without arguments, or pass ordinary attribute values with `:rows`.
Existing custom no-argument population methods continue to work; explicit rows
use the generic insertion path.

SQLite and MySQL advance automatic IDs for explicit inserts. PostgreSQL sequences
are advanced after the script succeeds, without lowering their existing values.
Sequence counters can have gaps after failed transactions, as with normal inserts.

Fixtures contain executable Raku code and should only be applied from trusted
projects. Values without a supported serializable representation are rejected.

## Rebuild a migration database

```sh
red migration drop-tables
red migration reset
red migration reset --force --connection=development
```

`drop-tables` removes managed model and historical tables plus all migration
bookkeeping. `reset` then reapplies the prepared migrations, including their seed
data. Both preserve the migration files and show a confirmation prompt unless
`--force` is supplied. Reset does not automatically apply fixtures. See
[versioned migrations](../migrations.md#remove-tables-and-rebuild-a-database)
for dependency handling and transaction behavior.
