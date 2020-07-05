# [Red ORM](https://github.com/FCO/Red)

[Red](https://github.com/FCO/Red) is an ORM for [Raku](https://raku.org) that tries to mimic [Raku](https://raku.org)'s `Positional` API but for querying databases.
[Red](https://github.com/FCO/Red) implements a custom Metamodel based on [Metamodel::ClassHOW](https://docs.raku.org/type/Metamodel::ClassHOW). You use its new `model`
keyword to describe your table and its relations as a Raku class.

The Red Metamodel exports a meta-method called `all` or `rs` and it returns an instance of a class called `Red::ResultSeq` that should be seen as a specialization
of the `Seq` Raku type, but its data is in the database. So `MyModel.^all` represents all rows in the table represented by `MyModel`, and
`MyModel.^all.grep: *.col1 > 3` represents all rows in the table represented by `MyModel` where the value of `col1` is higher than 3. The `grep` method (as do most of
the other ResultSeq methods) returns a new ResultSeq.

