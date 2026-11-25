class submethod BUILD (Red::Driver::SQLite $:: DBDish::SQLite::Connection :$!dbh, Str :$!database = ":memory:", Bool :$!use-experimental-regex = Bool::False, *%_) { #`(Submethod|4140302005336) ... }
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Data accepted by the SQLite driver constructor: dbh     : DBDish::SQLite object database: File name or C<:memory:> to a in memory DB (default) use-experimental-regex: Enable experimental SQL regex translation (default False)

### method begin

```raku
method begin() returns Mu
```

Begin transaction

### multi method should-drop-cascade

```raku
multi method should-drop-cascade() returns Mu
```

Does this driver accept drop table cascade?

### method sqlite-json-contains

```raku
method sqlite-json-contains(
    Str $value,
    Str $argument
) returns Str
```

Implements recursive JSON containment, with unordered array matching as in JSONB.

### method create-database

```raku
method create-database(
    Str:D $name
) returns Mu
```

Create a persistent SQLite database without replacing an existing file.

