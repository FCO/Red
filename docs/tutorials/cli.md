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
