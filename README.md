[![Build Status](https://travis-ci.org/FCO/Red.svg?branch=master)](https://travis-ci.org/FCO/Red)

Red
===

Take a look at our Wiki: [https://github.com/FCO/Red/wiki](https://github.com/FCO/Red/wiki)

Take a look at our Documentation: [https://fco.github.io/Red/](https://fco.github.io/Red/)

Red - A **WiP** ORM for Raku
----------------------------

INSTALL
-------

Install with (you need **rakudo 2018.12-94-g495ac7c00** or **newer**):

    zef install Red

SYNOPSIS
--------

```perl6
use Red:api<2>;

model Person {...}

model Post is rw {
    has Int         $.id        is serial;
    has Int         $!author-id is referencing{ Person.id };
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has Person      $.author    is relationship{ .author-id };
    has Bool        $.deleted   is column = False;
    has DateTime    $.created   is column .= now;
    has Set         $.tags      is column{
        :type<string>,
        :deflate{ .keys.join: "," },
        :inflate{ set(.split: ",") }
    } = set();
    method delete { $!deleted = True; self.^save }
}

model Person is rw {
    has Int  $.id            is serial; # an id field is not mandatory, but convenient
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };
    method active-posts { @!posts.grep: not *.deleted }
}

my $*RED-DB = database "SQLite";

Person.^create-table;
```

```sql
-- Equivalent to the following query:
CREATE TABLE person(
    id integer NOT NULL primary key
    AUTOINCREMENT,
    name varchar(255) NOT NULL
)
```

```perl6
Post.^create-table;
```

```sql
-- Equivalent to the following query:
CREATE TABLE post(
    id integer NOT NULL primary key AUTOINCREMENT,
    author_id integer NULL references person(id),
    title varchar(255) NOT NULL,
    body varchar(255) NOT NULL,
    deleted integer NOT NULL,
    created varchar(32) NOT NULL,
    tags varchar(255) NOT NULL,
    UNIQUE (title)
)
```

```perl6
my Post $post1 = Post.^load: :42id;
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.id = 42
```

```perl6
my Post $post1 = Post.^load: 42;
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.id = 42
```

```perl6
my Post $post1 = Post.^load: :title("my title");
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.title = ‘my title’
```

```perl6
my $person = Person.^create: :name<Fernando>;
```

```sql
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    ?
)
-- BIND: ["Fernando"]

-- SQLite needs an extra select:

SELECT
    person.id,
    person.name
FROM
    person
WHERE
    _rowid_ = last_insert_rowid()
LIMIT 1
```

```perl6
RETURNS:
Person.new(name => "Fernando")
```

```perl6
# Using Pg Driver for this block
{
    my $*RED-DB = database "Pg";
    my $person = Person.^create: :name<Fernando>;
}
```

```sql
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    $1
) RETURNING *
-- BIND: ["Fernando"]
```

```perl6
RETURNS:
Person.new(name => "Fernando")
```

```perl6
say $person.posts;
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.author_id = ?
-- BIND: [1]
```

```perl6
say Person.new(:2id)
    .active-posts
    .grep: { .created > now }
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    (
       post.author_id = ?
       AND (
           post.deleted == 0
           OR post.deleted IS NULL
       )
    )
    AND post.created > 1554246698.448671
-- BIND: [2]
```

```perl6
my $now = now;
say Person.new(:3id)
    .active-posts
    .grep: { .created > $now }
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    (
       post.author_id = ?
       AND (
           post.deleted == 0
           OR post.deleted IS NULL
       )
    )
    AND post.created > ?
-- BIND: [
--   3,
--   Instant.from-posix(
--       <399441421363/257>,
--       Bool::False
--   )
-- ]
```

```perl6
Person.^create:
    :name<Fernando>,
    :posts[
        {
            :title("My new post"),
            :body("A long post")
        },
    ]
;
```

```sql
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    ?
)
-- BIND: ["Fernando"]

SELECT
    person.id,
    person.name
FROM
    person
WHERE
    _rowid_ = last_insert_rowid()
LIMIT 1
-- BIND: []

INSERT INTO post(
    created,
    title,
    author_id,
    tags,
    deleted,
    body
)
VALUES(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
-- BIND: [
--   "2019-04-02T22:55:13.658596+01:00",
--   "My new post",
--   1,
--   "",
--   Bool::False,
--   "A long post"
-- ]

SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    _rowid_ = last_insert_rowid()
LIMIT 1
```

```perl6
my $post = Post.^load: :title("My new post");
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.title = ‘My new post’
-- BIND: []
```

```perl6
RETURNS:
Post.new(
   title   => "My new post",
   body    => "A long post",
   deleted => 0,
   created => DateTime.new(
       2019,
       4,
       2,
       23,
       7,
       46.677388,
       :timezone(3600)
   ),
   tags    => Set.new("")
)
```

```perl6
say $post.body;
```

```perl6
PRINTS:
A long post
```

```perl6
my $author = $post.author;
```

```perl6
RETURNS:
Person.new(name => "Fernando")
```

```perl6
$author.name = "John Doe";

$author.^save;
```

```sql
-- Equivalent to the following query:
UPDATE person SET
    name = ‘John Doe’
WHERE id = 1
```

```perl6
$author.posts.create:
    :title("Second post"),
    :body("Another long post");
```

```sql
-- Equivalent to the following query:
INSERT INTO post(
    title,
    body,
    created,
    tags,
    deleted,
    author_id
)
VALUES(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
-- BIND: [
--   "Second post",
--   "Another long post",
--   "2019-04-02T23:28:09.346442+01:00",
--   "",
--   Bool::False,
--   1
-- ]
```

```perl6
$author.posts.elems;
```

```sql
-- Equivalent to the following query:
SELECT
    count(*) as "data_1"
FROM
    post
WHERE
    post.author_id = ?
-- BIND: [1]
```

```perl6
RETURNS:
2
```

DESCRIPTION
-----------

Red is a *WiP* ORM for Raku.

### traits

  * `is column`

  * `is column{}`

  * `is id`

  * `is id{}`

  * `is serial`

  * `is referencing{}`

  * `is relationship{}`

  * `is table<>`

  * `is nullable`

### features:

#### relationships

Red will infer relationship data if you use type constraints on your properties.

```perl6
# Single file e.g. Schema.pm6

model Related { ... }


# belongs to
model MyModel {
    has Int     $!related-id is referencing( *.id, :model<Related> );
    has Related $.related    is relationship{ .id };
}

# has one/has many
model Related {
    has Int $.id is serial;
    has MyModel @.my-models is relationship{ .related-id };
}
```

If you want to put your schema into multiple files, you can create an "indirect" relationship, and Red will look up the related models as necessary.

```perl6
# MyModel.pm6
model MyModel {
    has Int     $!related-id is referencing{ :model<Related>, :column<id> };
    has         $.related    is relationship({ .id }, :model<Related>);
}

# Related.pm6
model Related {
    has Int $.id is serial;
    has     @.my-models is relationship({ .related-id }, :model<MyModel>);
}
```

If Red can’t find where your `model` is defined you can override where it looks with `require`:

```perl6
    has Int     $!related-id is referencing{ :model<Related>, :column<id>,
                                             :require<MyApp::Schema::Related> };
```

#### custom table name

```perl6
model MyModel is table<custom_table_name> {}
```

#### not nullable columns by default

Red, by default, has not nullable columns, to change it:

```perl6
#| This makes this model’s columns nullable by default
model MyModel is nullable {
    has Int $.col1 is column;               #= this column is nullable
    has Int $.col2 is column{ :!nullable }; #= this one is not nullable
}
```

#### load object from database

```perl6
MyModel.^load: 42;
MyModel.^load: id => 42;
```

#### save object on the database

```perl6
$object.^save;
```

#### search for a list of object

```perl6
Question.^all.grep: { .answer == 42 }; # returns a result seq
```

#### phasers

  * `before-create`

  * `after-create`

  * `before-update`

  * `after-update`

  * `before-delete`

  * `after-delete`

#### Temporary table

```perl6
model Bla is temp { ... }
```

#### Create table

```perl6
Question.^create-table;
Question.^create-table: :if-not-exists;
Question.^create-table: :unless-exists;
```

#### IN

```perl6
Question.^all.grep: *.answer ⊂ (3.14, 13, 42)
```

#### create

```perl6
Post.^create: :body("bla ble bli blo blu"), :title("qwer");


model Tree {
    has UInt   $!id        is id;
    has Str    $.value     is column;
    has UInt   $!parent-id is referencing{ Tree.id };

    has Tree   $.parent    is relationship{ .parent-id };
    has Tree   @.kids      is relationship{ .parent-id };
}

Tree.^create-table: :if-not-exists;

Tree.^create:
    :value<Bla>,
    :parent{:value<Ble>},
    :kids[
        {:value<Bli>},
        {:value<Blo>},
        {:value<Blu>}
    ]
;
```

AUTHOR
------

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
---------------------

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

