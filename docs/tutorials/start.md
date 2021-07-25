## Red starter tutorial

This document is an introduction tutorial which shows the most basic usage examples of Red.
For more in-depth introduction about Red architecture visit [Red architecture](tutorials/architecture) page.

### Models and tables

[Red](https://github.com/FCO/Red) is an Object-Relational Mapping (ORM) tool for Raku

Simply speaking, it allows you to "hide" the layer of interaction
with your relational database and work with Raku objects instead.

Currently, PostgreSQL and SQLite3 relation databases are supported.

Let's start with a simple table:

```sql
CREATE TABLE person(
   id integer NOT NULL PRIMARY KEY AUTOINCREMENT,
   name varchar(255) NOT NULL
);
```

With this query executed in your database console, a table named `person` was created with
two columns: `id` which is an integer ID of the record, it is a primary key and is
incremented automatically, and `name` which is a string of maximum 255 characters, which is not null.

In Red, each table is represented using a special type of class called "model". It can do
everything what a usual class can do, but also helps you to interact with your table.

Red models use `model` keyword instead of `class`:

```raku
model Person {
    has Int $.id is serial;
    has Str $.name is column is rw;
}

my $*RED-DB = database “SQLite”;
```

We described a model called `Person`. The first attribute `$.id` is typed to be `Int`
and is marked with [is serial](../api/Red/Traits) trait. This trait marks the column as a primary one with
autoincrement enabled. The next attribute `$.name` is marked with [is column](../api/Red/Traits) trait, which
means this attribute will be mapped onto a column in the table, and is typed as Str.

Note we don't need to specify that the column is not nullable, as it is the default.

The second statement specifies a database to work with. In this case,
an in-memory SQLite database is used, which means all changes will be lost after
the script termination. To avoid this, we can specify a name for the database file:

```raku
my $*RED-DB = database “SQLite”, database => 'test.sqlite3'; # Now a file `test.sqlite3` will be created
```

Next, we need to create a table itself:


```raku
Person.^create-table;
```

Methods marked with `^` are called "meta methods" and are used in Red
for all kinds of operations on models. In this case, calling `^create-table`
creates a table with name `person`.

### Insertion of new records

Let's insert a new record into it. In SQL it could be:

```sql
INSERT INTO person (name) VALUES 'John';
```

In Red we can express it this way:

```raku
my $person = Person.^create(name => 'John');
```

We call the `^create` method on type object `Person` and assign the result
to the `$person` variable. The assignment is not necessary:

```raku
Person.^create(name => 'John');
```

The `^create` method returns the created object to work with, though
this result can be simply ignored.

The `$.id` attribute is auto-generated and there is no need to specify it,
while `$.name` attribute must not be null, so we have to specify it:

```raku
Person.^create; # error
```

### Update of records

Let's try to update our record. In SQL it could be:

```sql
UPDATE person SET name = 'John Doe' WHERE id = 1;
```

To do the same in Red, we use setters and a call to `^save`:

```raku
$person.name = 'John Doe';
$person.^save;
```

All changes to an object that represents the record are lazy,
which means the database connection is not used until the `^save`
method is called.

The method `^save` is useful not only for UPDATE operation, but it can be used on
INSERT too:

```raku
my $person2 = Person.new(name => 'Joan'); # ^create is not used
$person2.^save; # does INSERT, not UPDATE
```

### Selecting records

Lets add some more records:

```raku
Person.^create(name => "Paul"); # Method call with parentheses and an arrow pair
Person.^create: :name<Miki>;    # Semicolon form of method call is used
```

Lets begin with selecting all records of the table:

```sql
SELECT * FROM person;
```

In Red, `^all` method is used:

```raku
for Person.^all -> $person { say $person }
```

Method `^all` returns an instance of class `Seq` that is a lazy sequence of records returned.

```sql
SELECT * FROM person WHERE person.name like 'Jo%';
```

The query above selects all records where name starts with 'Jo'. In Red, you can use Raku `grep`
method to specify clauses of the select query:

```raku
for Person.^all.grep(*.name.starts-with('Jo')) -> $person { say $person }
```

Note that this call chain will result into an equivalent of the SQL code above,
filtering values happens at the database level, not at Raku level.

```sql
SELECT * FROM person WHERE person.name like 'Jo%' AND person.id = 2;
```

To express the query above, calls to `grep` can be combined:

```raku
for Person.^all.grep(*.name.starts-with('Jo')).grep(*.id == 2) -> $person { say $person }
```

Alternatively, boolean operators can be used:

```raku
for Person.^all.grep({ $_.name.starts-with('Jo') && $_.id == 2}) -> $person { say $person }
```

### Selecting a single record

To get a single record, `^load` method is used. It accepts an arbitrary number of pairs
describing the object properties for the WHERE clause of a SELECT statement. One difference
between using `^all` and `^load` is that the `^load` method returns either a value or a `Nil`
if there are no fitting records, while `^all` returns a `Seq` that might come
with an arbitrary number of elements. The second difference is that `^all` can express
various SELECT statements, while `^load` is restricted to work with columns marked as PRIMARY
and UNIQUE only.

```raku
say Person.^load(id => 4); # correct
# when the primary column is unambiguous, only its value can be passed
say Person.^load(4);      # correct, same as `id => 4`
# however, `^load does not work for non-primary columns:
say Person.^load(:name<Foo>); # error
```

### Deleting rows

To delete rows, the `^delete` method is used. It can be called on an individual
object or on a model to delete all records:

```raku
# DELETE FROM person WHERE person.id = 42;
$p.^delete;
# DELETE FROM person;
Person.^delete;
```

Here, we covered basics of Red usage. Refer to Red cookbook
for different examples without a particular order or visit the next
tutorial in this series, related to expressing table relationships
using Red, [here](relationships).
