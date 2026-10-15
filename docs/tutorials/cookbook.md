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
    has Str         $.title     is unique;
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

### If there is a blog where a post has one or more tags and tags can have multiple tags.

```raku
use Red;

model PostTag {...}

model Post {
	has UInt    $.id        is serial;
	has Str     $.title     is unique;
	has PostTag @.post-tags is relationship{ .post-id };
	method tags { @.post-tags>>.tag }
}

model Tag {
	has Str $.name          is id;
	has PostTag @.post-tags is relationship{ .tag-id };
	method posts { @.post-tags>>.post }
}

model PostTag {
	has UInt $.post-id is column{ :id, :references{ .id },   :model-name<Post> };
	has Str  $.tag-id  is column{ :id, :references{ .name }, :model-name<Tag>  };
	has Post $.post    is relationship{ .post-id };
	has Tag  $.tag     is relationship{ .tag-id  };
}

red-defaults "SQLite";

schema(PostTag, Post, Tag).create;

my $a = Post.^create: :title<bla>, :post-tags[{ :tag{ :name<a> } }];

.say for $a.tags;
.say for Tag.^all.head.posts;
.say for Post.tags;
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
    method logins {
        self.^rs.join-model: :name<logged_buyer>, Login, -> $b, $l { $b.id == $l.source-id && $l.source eq "buyer" }
    }
}

model Seller {
    has $.id    is serial;
    has $.name  is column;
    method logins {
        self.^rs.join-model: :name<logged_seller>, Login, -> $b, $l { $b.id == $l.source-id && $l.source eq "seller" }
    }
}

my $comprador = Buyer.^create:  :name<Comprador>;
my $vendedor  = Seller.^create: :name<Vendedor>;

$comprador.logins.create;
$vendedor.logins.create;

.say for $comprador.logins;
.say for $vendedor.logins;
```

A new (and better) way to do this is using relationship receiving 2 arguments.
When a relationship receives 2 arguments and returns Red::AST instead of Red::Column,
it will be used to create a new join type using `join-model`.

```raku
model Buyer  { ... }
model Seller { ... }

model Login is table<logged_user> {
    has         $.id        is serial;
    has         $.source    is column;
    has UInt    $.source-id is referencing(*.id, :model<Buyer>);
    has Instant $.created   is column = now;
    has Buyer   $.buyer     is relationship{ $^b.id == $^a.source-id && $^a.source eq "buyer"  }
    has Seller  $.seller    is relationship{ $^b.id == $^a.source-id && $^a.source eq "seller" }
}

model Buyer {
    has UInt  $.id     is serial;
    has Str   $.name   is column;
    has Login @.logins is relationship{ $^a.id == $^b.source-id && $^b.source eq "buyer" }
}

model Seller {
    has UInt  $.id     is serial;
    has Str   $.name   is column;
    has Login @.logins is relationship{ $^a.id == $^b.source-id && $^b.source eq "seller" }
}

my $comprador = Buyer.^create:  :name<Comprador>;
my $vendedor  = Seller.^create: :name<Vendedor>;

$comprador.logins.create;
$vendedor.logins.create;

.say for $comprador.logins;
.say for $vendedor.logins;

say "Login: { .id }; Buyer: { .name with .buyer }; Seller: { .name with .seller }" for Login.^all;
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

## when foreign key and pk use the same column.

```
use Red:api<2>;

model B { ... }

model A is table<aa> {
    has Int $.id is serial;
    has Str $.name is column;
}

model B is table<bb> {
    # Here, we can use this syntax to make bb.a_id column references aa.id
    has Int $.a-id is column{ :id, :references{.id}, :model-name<A> };
    has A $.a is relationship{ .a-id };
    has Str $.name is column;
}

red-defaults default => database 'SQLite';

schema(A, B).create;

my $a = A.^create: :name('A');
B.^create: :$a, :name('b');
my $b = B.^load: :a-id($a.id);
$b.raku.say;
$b.a.raku.say
```

## Unique constraints with multiple column

Name a group of column to add them on a unique constraint (each column can be on more than one group).

```raku
model BBB {
    has Int $.id is serial;
    has Str $.a1 is unique<a b>;
    has Str $.a2 is unique<a b c d>;
    has Str $.a3 is unique<a>;
}
```
it will create a table like this:

```sql
CREATE TABLE b_b_b(
   id integer NOT NULL primary key AUTOINCREMENT,
   a1 varchar(255) NOT NULL ,
   a2 varchar(255) NOT NULL ,
   a3 varchar(255) NOT NULL ,
   UNIQUE (a1, a2),
   UNIQUE (a2),
   UNIQUE (a2),
   UNIQUE (a1, a2, a3)
)
```

## Submodel

If there is a model that can be divided into several different types, you can create submodels for that.

```raku
use Red;

model User {
   has Int $.id   is serial;
   has Str $.name is column;
   has Str $.role is column;
}

red-defaults "SQLite";

User.^create-table;

for <user admin root> -> $role {
	User.^create(:name("user " ~ ++$), :$role)
}

# Someday it will become:
# submodel Admin of User where *.role eq "admin";
subset Admin is sub-model of User where *.role eq "admin";

# Use as subset
say User.new(:role<admin>) ~~ Admin; # True
say User.new(:role<user>) ~~ Admin; # False

# List all admins
.say for Admin.^all;

# Create with right role
Admin.^create: :name("new admin");

# Load with the right role
say Admin.^load: 2;

# Delete filtering with right role
Admin.^delete;
```

## events

If you want to run something every time a query is made by Red.

```raku
Red.events.tap: &dd
```

and it will print `Red::Event`s like:

```raku
Red::Event.new(
  bind        => [],
  model       => MyModel,
  origin      => Red::Model,
  error       => Exception,
  metadata    => {},
  db-name     => "Red::Driver::SQLite",
  driver-name => Str,
  name        => Str,
  db          => Red::Driver::SQLite.new(
    database => ":memory:",
    events   => Supply.new,
  ),
  data        => Red::AST::CreateTable.new(
    name    => "my_model",
    temp    => Bool,
    columns => Array[Red::Column].new(
      Red::Column.new(
        attr           => my_model.id,
        attr-name      => "id",
        auto-increment => Bool::True,
        id             => Bool::True,
        name           => "id",
        name-alias     => "id",
        nullable       => Bool::False,
      ),
      Red::Column.new(
        attr           => my_model.text,
        attr-name      => "text",
        auto-increment => Bool::False,
        id             => Bool::False,
        name           => "text",
        name-alias     => "text",
        nullable       => Bool::False,
      )
    ),
    constraints => Array[Red::AST::Constraint].new(),
    comment     => Red::AST::TableComment,
  ),
)
```

And if you want to get events only from the driver you are using, you can use red-tap function.
and to emit your custom events, you can just:

```raku
Red.emit: "my data";
```

or use `red-emit` to emit for the current driver.

## JSON columns

Import `Red::Type::Json` and use `Json` as the column type. SQLite stores JSON text;
PostgreSQL uses JSONB. Pass Raku values rather than pre-encoded JSON strings.

```raku
use Red:api<2>;
use Red::Type::Json;

model Document {
    has UInt $.id is serial;
    has Json $.data is rw is column;
    has Json $.optional is rw is column{ :nullable };
    has Str $.selected-key is column;
    has Int $.selected-index is column;
}

Document.^create:
    :data({ :count(10), :items([1, 2, 3]), :unknown(Any) }),
    :selected-key<count>, :selected-index(1);

Document.^all.map(*.data<items>[1]);
Document.^all.map({ .data{.selected-key} });
Document.^all.map({ .data<items>[.selected-index] });

Document.^all.map({
    .data<count> += 2;
    .data<items>[.selected-index] = 42;
    .data<added> = { :enabled(True) };
}).save;

Document.^all.map({ .data<items>[0]:delete }).save;
Document.^all.map({ .data<added><enabled>:delete }).save;

Document.^all.grep({ .data<unknown>:exists });
Document.^all.grep({ .data<items>[0]:exists });
Document.^all.map(*.data<items>.elems);
Document.^all.grep({ .data.contains({ :items([42]) }) });
```

Keys may contain punctuation, quotes, backslashes, or Unicode. SQL expressions
can supply keys and indexes. Escaped object labels require a recent SQLite build;
older SQLite versions cannot address keys containing both quotes and dots.
Negative indexes count from the end; use
`.AT-POS(-1)` because Raku rejects a literal `[-1]` subscript.

Multiple changes to a JSON column in one `map` are composed in order. A later
expression referring to that column sees the earlier changes. For portable
nested updates, create the parent object or array first: PostgreSQL's
`jsonb_set` does not create missing intermediate containers.

`:exists` distinguishes missing paths from members containing JSON null.
`Any` represents JSON null; the `Json` type object represents SQL NULL for a
nullable column and is also returned for a missing path. A JSON column without
an explicit default starts as `Json`. Strings such as `'123'`, `'null'`, and
`'{"x":1}'` remain strings. Invalid JSON and unsupported values raise
`X::Red::Json` during inflation or deflation.

`.elems` counts object members or array elements. Scalars have one element,
including JSON null and SQL NULL; missing JSON paths have zero elements. This
also applies to projected scalars after a SELECT boundary. Non-JSON scalars have
one element, while `.elems` on a ResultSeq counts rows. `.contains` performs recursive JSON containment. Objects
match a subset of their members; arrays ignore order and duplicate requirements,
and can contain a primitive value. SQLite implements containment with a recursive
query over `json_tree`; PostgreSQL uses the native JSONB containment operator.
For large documents, PostgreSQL's native JSONB operations are preferable.

## Chaining projected values

A SQL `map` produces one element per row. That element can be a scalar, a Hash,
an Array, or a List, and containers can be nested. Subsequent `map`, `grep`, and
`sort` blocks receive the projected element rather than the original model.

```raku
my $values = MyModel.^all
    .map({ .col1 + .col2 })
    .grep(* > 3)
    .map({ "something: $_" });

my $records = MyModel.^all.map({
    %(col1 => .col1, something-else => .col2 ~ .col3)
});
my $labels = $records.map({ .<something-else> });

my $pairs = MyModel.^all.map({ [.col1, .col2] });
my $second = $pairs.grep({ .[0] > 3 }).map({ .[1] });

my $nested = MyModel.^all.map({
    %(:pair([.col1, .col2]), :details(%(:label(.col3))))
});
my $nested-labels = $nested.map({ .<details><label> });
```

These operations remain lazy: constructing the chain does not execute SQL.
Iteration runs one statement containing the required derived tables. Each row
is reconstructed into its projected shape, preserving Array versus List and
retaining column converters, including JSON and custom Red types. Arrays and
Lists are not implicitly flattened into separate result elements. Empty
containers still produce one element per source row.

For scalar projections, `.sort` without arguments orders by the projected value
in ascending order; `.sort(-*)` orders in descending order. `.sort(*)` is invalid,
matching native Array and Seq sorting. Models and Hash, Array, or List projections
require a Callable selecting the field or position to order by.

Red substitutes safe projected expressions into subsequent `map`, `grep`, and
`sort` operations, allowing them to share one SELECT. For example:

```raku
Bla.^all.map(*.bla).grep(* > 1).map(* + 42)
```

produces the equivalent of:

```sql
SELECT bla + 42 AS data FROM bla WHERE bla > 1
```

This also works for computed expressions and fields in nested containers. Each
occurrence of a substituted expression retains its own bound parameters.

Red retains a `FROM (SELECT ...)` boundary for pagination, grouping, aggregate
and DISTINCT projections, subqueries, volatile or unclassified functions, and
potentially failing operations such as division and non-identity casts. Identity
casts, widening casts from numeric types to Numeric, and numeric-to-text casts
used by string interpolation are safe to substitute.
Filtering after `.head(2)` therefore filters those two rows, rather than filtering
the complete source before taking two rows. Later safe operations can share the
outer SELECT. Ordering crosses boundaries through internal fields that do not
appear in the result elements. No configuration is needed to enable fusion.

`tail(n)` returns a lazy ResultSeq containing the last `n` rows in their original
order. Red reverses the SQL ordering, applies `LIMIT n`, and restores the original
ordering in an outer SELECT. Filters and maps after `tail` apply to those selected
rows. `reverse` also stays in SQL and reverses every ordering component. Both
operations preserve any preceding `head` or `skip` window.

```raku
my $last-values = Bla.^all.map(*.bla).grep(* > 1).tail(7)
    .map(* * 10).grep(* < 100);
my $descending = Bla.^all.sort(*.bla).reverse;
my $last-value = Bla.^all.map(*.bla).tail;
```

Without an explicit `sort`, these operations use ascending primary-key order,
including all components of a composite key. Red preserves these keys internally
through scalar and container projections. Aggregate and DISTINCT projections lose
that row identity and require explicit sorting. Queries without an available key
use the native Seq fallback; with `$*RED-FALLBACK = False`, they raise
`X::Red::Projection`. Callable tail counts, such as `.tail(*-3)`, retain native
Seq behavior. Explicit sorting does not add primary-key tie-breakers; include them
in the sort block when ties must have a deterministic order. NULL ordering follows
the selected database driver.

`head` and `first` return the projected element. Row counts, query existence,
and scalar `Bag`, `Set`, and `classify` operations use the projected query and
its filters. Independent chains derived from the same query do not modify each
other. Subqueries use distinct aliases so correlated references remain valid.

Projection shapes must be known while Red analyzes the block. Hash keys and
container positions are static; conditional branches must have matching shapes
and their expressions must have compatible SQL types. Use `%()` explicitly when
constructing Hashes containing expressions. Arbitrary object constructors and
other unsupported operations retain the existing runtime fallback behavior;
set `my $*RED-FALLBACK = False` to require SQL translation. Unsupported shapes
raise `X::Red::Projection` with fallback disabled.

Projected queries are read-only: `create`, `save`, and `delete` reject them.
Updating maps on model queries retain the existing explicit persistence flow:

```raku
MyModel.^all.grep(*.col1 > 3).map({ .col1 = 42 }).save;
```

The projection representation has internal rebinding and materialization hooks
for future shapes; it is not a public custom-object projection API.
