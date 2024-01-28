class submethod BUILD (Red::Driver::SQLite: DBDish::SQLite::Connection :$!dbh, Str :$!database = ":memory:", *%_) { #`(Submethod|139711220954160) ... }
-------------------------------------------------------------------------------------------------------------------------------------------------------

Data accepted by the SQLite driver constructor: dbh : DBDish::SQLite object database: File name or C<:memory:> to a in memory DB (default)

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

