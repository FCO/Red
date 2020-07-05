# [Red ORM](https://github.com/FCO/Red)

[Red](https://github.com/FCO/Red) is a ORM for [Raku](https://raku.org) that tries to mimic [Raku](https://raku.org)'s `Positional`'s API but to query databases.
For doing that [Red](https://github.com/FCO/Red) implements a custom Metamodel based on [Metamodel::ClassHOW](https://docs.raku.org/type/Metamodel::ClassHOW).
To use that, you can use the `model` keyword to describe your table and it's relations as a Raku class.

The Red Metamodel exports a meta-method called `all` or `rs` and it returns an instance of a class called `Red::ResultSeq` that should be seen as a expecialization
of the `Seq` raku's type but it's data is on the database. So `MyModel.^all` represents all rows on the table represented by `MyModel`, and
`MyModel.^all.grep: *.col1 > 3` represents all rows on the table represented by `MyModel` where the value of `col1` is higher than 3. The `grep` method (as most of
the other ResultSeq methods) returns a new ResultSeq.

