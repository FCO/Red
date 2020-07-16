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

### Create with childs

If you want to create a Person with several Posts (the model is defined on the previous example):

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

### Create related

If you have a Person and want to create a post it authored:

```raku
$person.posts.create: :title("New post from { $person.name }"), :body("Lorem ipsum");
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

## Seq

If I want to run a grep on database and a map on process.

```raku
.say for Bla.^all.grep(*.ble > 10).Seq.map: *.bli
```

## Multi column primary key

How should I create a multi-column primary key?

```raku
model BankAccount {
    has Str $.sort-number is id;    
    has Str $.acc-number  is id;    
}
```

## Multi column unique constraints

How should I create a multi-column unique counstraint?

```raku
model BankAccount {
    has Str $.sort-number is column;
    has Str $.acc-number  is column;

    ::?CLASS.^add-unique-constraint: { .sort-number, .acc-number }
}
```

in the future it will probably be possible to do:

```raku
model BankAccount {
    has Str $.sort-number is unique<sort-acc>;
    has Str $.acc-number  is unique<sort-acc>;
}
```

## Create inter dependent table

How to create a table that depends of another table that depends on the first one?

```raku
model Bla {
   has UInt $.id     is serial;
   has UInt $.ble-id is referencing(*.id, :model<Ble>);
}

model Ble {
   has UInt $.id     is serial;
   has UInt $.bla-id is referencing(*.id, :model<Bla>);
}

red-defaults "Pg";

schema(Bla, Ble).create
```

and it will run this SQL:

```sql
BEGIN;
CREATE TABLE bla(
   id serial NOT NULL primary key,
   ble_id integer NULL 
);
CREATE TABLE ble(
   id serial NOT NULL primary key,
   bla_id integer NULL 
);
ALTER TABLE bla
   ADD CONSTRAINT bla_ble_id_ble_id_fkey FOREIGN KEY (ble_id) REFERENCES ble(id);
ALTER TABLE ble
   ADD CONSTRAINT ble_bla_id_bla_id_fkey FOREIGN KEY (bla_id) REFERENCES bla(id);
COMMIT;
```

## Phasers

If I want to run some code every time before I save an obj on database.

```raku
model MyModel {
   has $!id   is serial;
   has $.text is column is rw;

   method !log is before-create is before-update { say "saving: $!text" }
}

MyModel.^create-table;

my $a = MyModel.^create: :text("just testing");

$a.text = "Changing the text";

$a.^save
```

That prints:

```
saving: just testing
saving: Changing the text
```

and the existing phasers are:

1. `is before-create`
1. `is after-create`
1. `is before-update`
1. `is after-update`
1. `is before-delete`
1. `is after-delete`

## N-M Relationship

If I have a table of sentences in different languages and another table linking each sentence in a language to another sentence in a different language and 
want to find the translations.

```raku
model Sentence {
    has UInt $.id          is serial;
    has Str  $.lang        is column;
    has Str  $.sentence    is column;
    has      @.links-to    is relationship(*.id-to, :model<Link>);
    has      @.links-from  is relationship(*.id-from, :model<Link>);

    multi method translate(::?CLASS:D: :to($lang)) {
        $.links-from.first(*.to-sentence.lang eq $lang).to-sentence
    }
    multi method translate(::?CLASS:U: $sentence, :from($lang) = "eng", :$to) {
        Link.^all.first({
            .from-sentence.sentence eq $sentence
                    && .from-sentence.lang eq $lang
                    && .to-sentence.lang eq $to
        })
                .to-sentence
    }
}

model Link {
    has UInt $.id-from       is column{:id, :references(*.id), :model-name<Sentence>};
    has UInt $.id-to         is column{:id, :references(*.id), :model-name<Sentence>};
    has      $.to-sentence   is relationship(*.id-to  , :model<Sentence>);
    has      $.from-sentence is relationship(*.id-from, :model<Sentence>);
}

say Sentence.translate("hi", :from<english>, :to<portuguese>).sentence;
my @portuguese := Sentence.^all.grep: *.lang eq "portuguese";
my $oi = @portuguese.first(*.sentence eq "oi");
$oi.translate(:to<spanish>).sentence;
```

### Create Related

To add a new translation

```raku
$oi.links-from.create: :to-sentence{ :lang<esperanto>, :sentence<Saluton> };
```

## Custom join

If there is something you'd like to relationate but that's not a relationship. Something you'll probably do only once but that's not a relationship from the model.
You can use a custom join with `ResultSeq.join-model`.

```raku
use Red:api<2>;

model A is table<AAA> { has $.id is serial; has $.A1 is column; has $.A2 is column }
model B is table<BBB> { has $.id is serial; has $.B1 is column; has $.B2 is column }

red-defaults "SQLite" ;

schema(A, B).create;

A.^create: :A1(^10 .pick), :A2(^10 .pick) for ^10;
B.^create: :B1(^10 .pick), :B2(^10 .pick) for ^10;

my $*RED-DEBUG = True;
.say for A.^all.grep(*.A2 > 3).join-model(B, *.A1 == *.B1).map({ "{ A.A2 } -> { .B2 }" })
```

That would run:

```
SQL : SELECT
   AAA.A2 || ' -> ' || b_1.B2 as "data_1"
FROM
   AAA
    INNER JOIN BBB as b_1 ON AAA.A1 = b_1.B1
WHERE
   AAA.A2 > 3
BIND: []
8 -> 1
8 -> 3
6 -> 9
9 -> 1
9 -> 3
9 -> 7
9 -> 9
```

### Source and Source-id

Another reason to use custom joins is to create one single connection to multiple tables (source/source_id).
That's not a good pattern, but you can do it if you want.

```raku
model Login is table<logged_user> {
    has         $.id        is serial;
    has         $.source    is column;
    has UInt    $.source-id is referencing(*.id, :model<Buyer>);
    has Instant $.created   is column = now;
}

model Buyer {
    has $.id    is serial;
    has $.name  is column;
    method login {
        self.^rs.join-model: :name<logged_buyer>, Login, -> $b, $l { $b.id == $l.source-id && $l.source eq "buyer" }
    }
}

model Seller {
    has $.id    is serial;
    has $.name  is column;
    method login {
        self.^rs.join-model: :name<logged_seller>, Login, -> $b, $l { $b.id == $l.source-id && $l.source eq "seller" }
    }
}

my $comprador = Buyer.^create:  :name<Comprador>;
my $vendedor  = Seller.^create: :name<Vendedor>;

$comprador.login.create;
$vendedor.login.create;

.say for $comprador.login;
.say for $vendedor.login;
```

## union/intersect/minus

If you need the union, intersection or subtraction of two (or more) `ResultSeq`s

```raku
.say for MyModel.^all.grep(*.text.starts-with: "a") ∪ MyModel.^all.grep(*.text.starts-with: "b");
.say for MyModel.^all.grep(*.text.starts-with: "a") ∩ MyModel.^all.grep(*.text.ends-with: "s");
.say for MyModel.^all.grep(*.text.starts-with: "a") ⊖ MyModel.^all.grep(*.text.ends-with: "s");
```

## in

If you want to filter rows where a column can be one of multiple values.

```raku
.say for MyModel.^all.grep: *.text ⊂ <bla ble bli>
```

### in ResultSeq

But if the options are on the database.

```raku
.say for MyModel.^all.grep: *.text ⊂ TextOptions.^all.grep: *.id > 15
```

## classify

If you need to classify your rows based in something and only get one category by time.

```raku
my %classes := Student.^all.classify: *.class;
say %classes.keys;
.say for %classes<1a>;
```

that would run:

```
SQL : SELECT
   DISTINCT(student.class) as "data_1"
FROM
   student
BIND: []

SQL : SELECT
   student.id , student.name , student.class 
FROM
   student
WHERE
   student.class = ?
BIND: ["1a"]
```
