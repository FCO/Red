# Special Vars

## `$*RED-DB`

This is the variable where [Red](https://github.com/FCO/Red) stores the database connection.

```perl6
use Red;
my $*RED-DB = database "SQLite";
```

You should use [`red-do()`](https://fco.github.io/Red/api/Red/Do.html) and/or [`red-defaults()`](https://fco.github.io/Red/api/Red/Do.html) instead.

## `$*RED-DEBUG`

When this variable is set to a true-ish value [Red](https://github.com/FCO/Red) will print the generated `SQL`s to `$*OUT`.

```perl6
my $*RED-DEBUG = True;
Model.^create-table;
```

Output
```
SQL : CREATE TABLE model(
   id integer NOT NULL primary key 
)
BIND: []
```

## `$*RED-DEBUG-RESPONSE`

When this variable is set to a true-ish value [Red](https://github.com/FCO/Red) will print the response from the SQL query to `$*OUT`.

```perl6
my $*RED-DEBUG-RESPONSE = True;
Model.^create: :42id
```

Output
```
{id => 42}
```

## `$*RED-DEBUG-AST`

When this variable is set to a true-ish value [Red](https://github.com/FCO/Red) will print the generated `AST` to `$*OUT`.

```perl6
my $*RED-DEBUG-AST = True;
Model.^create: :42id
```

Output
```
Red::AST::Insert:
    id
```

## `$*RED-COMMENT-SQL`

When this variable is set to a true-ish value [Red](https://github.com/FCO/Red) will add comments about where in the code it was called on the `SQL query`.

```perl6
my $*RED-COMMENT-SQL = True;
Model.^create: :42id
```

## `$*RED-FALLBACK`

`Bool`, defines if Red should fallback to original methods if the Red one has failed.
