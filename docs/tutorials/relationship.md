# Relationships

Relationships in [Red](https://github.com/FCO/Red) are defined by the `is relationship` trait. It should receive (at least) a Str named parameter called `:model`
that represents the related model, a Callable positional parameter that will return one (or more) referencing columns, and it must have a sigil. The sigil can be:

- `$` - Represents a `belongs to` relationship that "stores" only 1 element. [Red](https://github.com/FCO/Red) will run the callable passing the model itself as the only parameter.

- `@` - Represents a `has many` relationship that "stores" a `ResultSeq` of elements. [Red](https://github.com/FCO/Red) will run the callable passing the model
  defined by the `:model` named parameter.

(for the experimental `has-one`, please take a look at [experimental doc](experimental.md))

## So, for example:

```raku
# Person.rakumod
use Red:ver<2>;

model Person {
  has UInt $!id    is serial;
  has Str  $.name  is column;
  has      @.books is relationship(*.author-id, :model<Book>);
}
```

```raku
# Book.rakumod
use Red:ver<2>;

model Book {
  has UInt $!id        is serial;
  has Str  $.name      is column;
  has UInt $!author-id is referencing(*.id, :model<Person>);
  has      $.author    is relationship(*.author-id, :model<Person>);
}
```

Book has a foreign key ($!author-id) that references `Person.id` (this is defined by the `is referencing` trait). And it also has a relationship ($.author)
that's auto pre-fetched using a `join` based on `book.author_id = person.id`.

Person has no foreign key but it does have a relationship (`@.books`) that isn't pre-fetched because it's a `has many` relationship. So when its value is accessed
a new query is run.

On that example, to create a new book related to (written by) a given person, one could do something like:

```raku
my $author = Person.^all.first: *.name eq "Chico Buarque";
$author.books.create: :name<Benjamin>;
```

As mentioned, `@.books` is a `ResultSeq`, so it accepts any of its methods, eg:

```raku
$author.books.grep(*.starts-with: "Ben").elems
```

For getting the number of books written by "Chico Buarque" that starts with "Ben".
