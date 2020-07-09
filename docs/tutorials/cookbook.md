# [Red](https://github.com/FCO/Red) Cook Book

## Pagination

I have a model `ListOfStuff` with too many rows and I want to paginate it.

```raku
my @a := ListOfStuff.^all.batch(10); # Returns a ResultSeqSeq (no SQL is run)
.say for @a[0];                      # prints every element from the first page
                                     # (now Red will run the query)
.say for @a[5];                      # query and prints the 6th page
```

## Relationship

I have two models `Post` and `Person` and I'd like to from a Post object get its author (a Person object)
and from a Person object get all Posts that person has written.

```raku
model Post is rw {
    has Int         $.id        is serial;
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has Int         $!author-id is referencing{ :model<Person>, :column<id> };
    has             $.author    is relationship( *.author-id, :model<Person> );
}

model Person is rw {
    has Int  $.id    is serial;
    has Str  $.name  is column;
    has      @.posts is relationship( *.author-id, :model<Post> );
}
```

And you can access the Post's author just using:

```raku
$post.author
```

it's pre-fetched when the `$post` is gotten from the database.

And to list all posts from a given Person:

```raku
.name.say for $person.posts
```

And if you want to create a Person with several Posts, it's easy to do:

```raku
Person.new:
  :name<Author1>,
  :posts[
    { :title("First post title") , :body("A very long body to the first blog post")  },
    { :title("Second post title"), :body("A very long body to the second blog post") },
    { :title("Third post title") , :body("A very long body to the third blog post")  },
  ]
;
```

## Inflators/Deflators

If you want to use a custom type on your model and store it in the database.

```raku
class CustomType {
  has @.a;
  method new(@a) {
    self.bless: :@a
  }
  method Str {
    @!a.join: ","
  }
}

sub inflate(Str $varchar     --> CustomType) { CustomType.new: $varchar.split: "," }
sub deflate(CustomType $data --> Str       ) { $data.Str }

model Bla {
   has UInt       $.id  is serial;
   has CustomType $.bla is column{ :type<varchar>, :&inflate, :&deflate }
}

red-defaults "SQLite";

Bla.^create-table;

my $a = Bla.^create: :bla(CustomType.new: <bla ble>);

say $a.bla;
```
