Red
===

Take a look at our Wiki: [https://github.com/FCO/Red/wiki](https://github.com/FCO/Red/wiki)

Red - A **WiP** ORM for perl6
-----------------------------

INSTALL
-------

Install with (you need **rakudo 2018.12-94-g495ac7c00** or **newer**):

    zef install Red

SYNOPSIS
--------

```perl6
use Red;

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
        :deflate{ .keys.join: “,” },
        :inflate{ set(.split: “,”) }
    } = set();
    method delete { $!deleted = True; self.^save }
}

model Person is rw {
    has Int  $.id            is serial;
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };
    method active-posts { @!posts.grep: not *.deleted }
}

my $*RED-DB = database “SQLite”;

Person.^create-table;                                   # SQL : CREATE TABLE person(
                                                        #    id integer NOT NULL primary key
                                                        #       AUTOINCREMENT,
                                                        #    name varchar(255) NOT NULL
                                                        # )
                                                        # BIND: []

Post.^create-table;                                     # SQL : CREATE TABLE post(
                                                        #    id integer NOT NULL primary key
                                                        #       AUTOINCREMENT,
                                                        #    author_id integer NULL
                                                        #       references person(id),
                                                        #    title varchar(255) NOT NULL,
                                                        #    body varchar(255) NOT NULL,
                                                        #    deleted integer NOT NULL,
                                                        #    created varchar(32) NOT NULL,
                                                        #    tags varchar(255) NOT NULL,
                                                        #    UNIQUE (title)
                                                        # )
                                                        # BIND: []

my Post $post1 = Post.^load: :42id;                     # SQL : SELECT
                                                        #    post.id,
                                                        #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    post.id = 42
                                                        # BIND: []

my Post $post1 = Post.^load: 42;                        # SQL : SELECT
                                                        #    post.id,
                                                        #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    post.id = 42
                                                        # BIND: []

my Post $post1 = Post.^load: :title(“my title”);        # SQL : SELECT
                                                        #    post.id,
                                                        #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    post.title = ‘my title’
                                                        # BIND: []

my $person = Person.^create: :name<Fernando>;           # SQL : INSERT INTO person(
                                                        #    name
                                                        # )
                                                        # VALUES(
                                                        #    ?
                                                        # )
                                                        # BIND: [“Fernando”]
                                                        #
                                                        # SQLite needs an extra select:
                                                        #
                                                        # SQL : SELECT
                                                        #    person.id,
                                                        #    person.name
                                                        # FROM
                                                        #    person
                                                        # WHERE
                                                        #    _rowid_ = last_insert_rowid()
                                                        # LIMIT 1
                                                        # BIND: []
                                                        #
                                                        # RETURNS:
                                                        # Person.new(name => “Fernando”)

{
    my $*RED-DB = database “Pg”;                        # Using Pg Driver for this block

    my $person = Person.^create: :name<Fernando>;       # SQL : INSERT INTO person(
                                                        #    name
                                                        # )
                                                        # VALUES(
                                                        #    $1
                                                        # ) RETURNING *
                                                        # BIND: [“Fernando”]
                                                        #
                                                        # RETURNS:
}                                                       # Person.new(name => “Fernando”)

say $person.posts;                                      # SQL : SELECT
                                                        #    post.id,
                                                        #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    post.author_id = ?
                                                        # BIND: [1]

say Person.new(:2id)                                    # SQL : SELECT
    .active-posts                                       #    post.id,
    .grep: { .created > now }                           #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    (
                                                        #       post.author_id = ?
                                                        #       AND (
                                                        #           post.deleted == 0
                                                        #           OR post.deleted IS NULL
                                                        #       )
                                                        #    )
                                                        #    AND post.created > 1554246698.448671
                                                        # BIND: [2]

my $now = now;
say Person.new(:3id)                                    # SQL : SELECT
    .active-posts                                       #    post.id,
    .grep: { .created > $now }                          #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    (
                                                        #       post.author_id = ?
                                                        #       AND (
                                                        #           post.deleted == 0
                                                        #           OR post.deleted IS NULL
                                                        #       )
                                                        #    )
                                                        #    AND post.created > ?
                                                        # BIND: [
                                                        #   3,
                                                        #   Instant.from-posix(
                                                        #       <399441421363/257>,
                                                        #       Bool::False
                                                        #   )
                                                        # ]

Person.^create:                                         # SQL : INSERT INTO person(
    :name<Fernando>,                                    #    name
    :posts[                                             # )
        {                                               # VALUES(
            :title(“My new post”),                      #    ?
            :body(“A long post”)                        # )
        },                                              # BIND: [“Fernando”]
    ]                                                   # SQL : SELECT
;                                                       #    person.id,
                                                        #    person.name
                                                        # FROM
                                                        #    person
                                                        # WHERE
                                                        #    _rowid_ = last_insert_rowid()
                                                        # LIMIT 1
                                                        # BIND: []
                                                        # Nil
                                                        # SQL : INSERT INTO post(
                                                        #    created,
                                                        #    title,
                                                        #    author_id,
                                                        #    tags,
                                                        #    deleted,
                                                        #    body
                                                        # )
                                                        # VALUES(
                                                        #    ?,
                                                        #    ?,
                                                        #    ?,
                                                        #    ?,
                                                        #    ?,
                                                        #    ?
                                                        # )
                                                        # BIND: [
                                                        #   “2019-04-02T22:55:13.658596+01:00”,
                                                        #   “My new post”,
                                                        #   1,
                                                        #   “”,
                                                        #   Bool::False,
                                                        #   “A long post”
                                                        # ]
                                                        # SQL : SELECT
                                                        #    post.id,
                                                        #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    _rowid_ = last_insert_rowid()
                                                        # LIMIT 1
                                                        # BIND: []

my $post = Post.^load: :title(“My new post”);           # SQL : SELECT
                                                        #    post.id,
                                                        #    post.author_id as “author-id”,
                                                        #    post.title,
                                                        #    post.body,
                                                        #    post.deleted,
                                                        #    post.created,
                                                        #    post.tags
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    post.title = ‘My new post’
                                                        # BIND: []
                                                        #
                                                        # RETURNS:
                                                        # Post.new(
                                                        #   title   => “My new post”,
                                                        #   body    => “A long post”,
                                                        #   deleted => 0,
                                                        #   created => DateTime.new(
                                                        #       2019,
                                                        #       4,
                                                        #       2,
                                                        #       23,
                                                        #       7,
                                                        #       46.677388,
                                                        #       :timezone(3600)
                                                        #   ),
                                                        #   tags    => Set.new(“”)
                                                        # )

say $post.body;                                         # PRINTS:
                                                        # A long post

my $author = $post.author;                              # RETURNS:
                                                        # Person.new(name => “Fernando”)
$author.name = “John Doe”;

$author.^save;                                          # SQL : UPDATE person SET
                                                        #    name = ‘John Doe’
                                                        # WHERE id = 1

$author.posts.create:                                   # SQL : INSERT INTO post(
    :title(“Second post”),                              #    title,
    :body(“Another long post”),                         #    body,
;                                                       #    created,
                                                        #    tags,
                                                        #    deleted,
                                                        #    author_id
                                                        # )
                                                        # VALUES(
                                                        #    ?,
                                                        #    ?,
                                                        #    ?,
                                                        #    ?,
                                                        #    ?,
                                                        #    ?
                                                        # )
                                                        # BIND: [
                                                        #   “Second post”,
                                                        #   “Another long post”,
                                                        #   “2019-04-02T23:28:09.346442+01:00”,
                                                        #   “”,
                                                        #   Bool::False,
                                                        #   1
                                                        # ]

$author.posts.elems;                                    # SQL : SELECT
                                                        #    count(*) as “data_1”
                                                        # FROM
                                                        #    post
                                                        # WHERE
                                                        #    post.author_id = ?
                                                        # BIND: [1]
                                                        #
                                                        # RETURNS:
                                                        # 2
```

DESCRIPTION
-----------

Red is a *WiP* ORM for perl6. It’s not working yet. My objective publishing is only ask for help validating the APIs.

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
    has Int     $!related-id is referencing{ Related.id };
    has Related $.related    is relationship{ .id };
}

# has one/has many
model Related {
    has Int $.id is serial;
    has MyModel @.my-models is relationship{ .related-id };
}
```

If you want to put your schema into multiple files, you can create an “indirect” relationship, and Red will look up the related models as necessary.

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
model MyModel is nullable {                 # is nullable makes this model’s columns nullable by default
    has Int $.col1 is column;               # this column now is nullable
    has Int $.col2 is column{ :!nullable }; # this column is not nullable
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

    Post.^create: :body(“bla ble bli blo blu”), :title(“qwer”);

    model Tree {
        has UInt   $!id        is id;
        has Str    $.value     is column;
        has UInt   $!parent-id is referencing{ Tree.id };

        has Tree   $.parent    is relationship{ .parent-id };
        has Tree   @.kids      is relationship{ .parent-id };
    }

    Tree.^create-table: :if-not-exists;

    Tree.^create: :value<Bla>, :parent{:value<Ble>}, :kids[{:value<Bli>}, {:value<Blo>}, {:value<Blu>}];

AUTHOR
------

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
---------------------

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

