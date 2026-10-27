# Relationships

Relationships in [Red](https://github.com/FCO/Red) are defined by the `is relationship` trait. It should receive (at least) a Str named parameter called `:model`
that represents the related model, a Callable positional parameter that will return one (or more) referencing columns, and it must have a sigil. The sigil can be:

- `$` - Represents a `belongs to` relationship that "stores" only 1 element. [Red](https://github.com/FCO/Red) will run the callable passing the model itself as the only parameter.

- `@` - Represents a `has many` relationship that "stores" a `ResultSeq` of elements. [Red](https://github.com/FCO/Red) will run the callable passing the model
  defined by the `:model` named parameter.

- `$` with the `:has-one` option - Represents a `has one` relationship: the foreign key lives on the *other* model's table.
  Accessing it returns the related object (or an undefined creation context when empty — see "creating through a scalar
  relationship" below). On `.^create`, Red fills the foreign key on the related row automatically.

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

## has-one

A scalar relationship declared with `:has-one` means "the other table holds the foreign key". For example, an account
has one profile, and the `profile` table holds the `account-id`:

```raku
model Profile { ... }

model Account {
    has UInt    $.id      is serial;
    has Str     $.name    is column;
    has Profile $.profile is relationship(*.account-id, :model<Profile>, :has-one);
}

model Profile {
    has UInt $.id         is serial;
    has UInt $.account-id is referencing(*.id, :model<Account>);
    has Str  $.bio        is column;
    has      $.account    is relationship(*.account-id, :model<Account>);
}
```

## Creating through a scalar relationship

An empty scalar relationship returns an undefined, false type object carrying the relationship's creation context,
rather than `Nil`. Call `.^create` on that object to create the related row and fill the foreign key automatically:

```raku
my $parent  = $child.parent.^create(:name<parent>);

# For a relationship declared with :has-one:
my $profile = $account.profile.^create(:bio<hello>);
```

For a belongs-to relationship, Red saves the foreign key on the existing source row. For `:has-one`, Red supplies
the source key to the new related row. The source must already be saved. Both writes participate in one transaction;
a failed operation rolls back its writes and restores the source's attribute and dirty state. Inside a transaction,
the operation uses a savepoint.

Existing relationships continue to return their related instances. An empty relationship still tests false and
undefined, but code that checks specifically for `Nil` should use `.defined` instead. Creation uses `.^create`,
while plural relationships continue to use `.create`.
