# [Red ORM](https://github.com/FCO/Red)

[Red](https://github.com/FCO/Red) is a ORM for [Raku](https://raku.org) that tries to mimic [Raku](https://raku.org)'s `Positional`'s API but to query databases.
For doing that [Red](https://github.com/FCO/Red) implements a custom Metamodel based on [Metamodel::ClassHOW](https://docs.raku.org/type/Metamodel::ClassHOW).
To use that, you can use the `model` keyword to describe your table and it's relations as a Raku class.

The Red Metamodel exports a meta-method called `all` or `rs`, which returns an instance of a class called `Red::ResultSeq`. `ResultSeq` is essentially a 
specialization  of Raku’s `Seq` type for data is on the database. So `MyModel.^all` represents all rows on the `MyModel` table, and 
`MyModel.^all.grep: *.col1 > 3` represents all rows on the `MyModel` table where the value of `col1` is higher than 3. The `grep` method (and most of the other 
`ResultSeq` methods) returns a new `ResultSeq`.


