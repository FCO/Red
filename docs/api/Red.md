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

Person.^create-table;
Post.^create-table;

my Post $post1 = Post.^load: :42id;
my Post $post2 = Post.^load: 42;
my Post $post3 = Post.^load: :title(“my title”);

my $person = Person.^create: :name<Fernando>;
{
    my $*RED-DB = database “Pg”;
    my $person = Person.^create: :name<Fernando>;
}

say $person.posts;

say Person.new(:2id)
    .active-posts
    .grep: { .created > now }
;

my $now = now;

say Person.new(:3id)
    .active-posts
    .grep: { .created > $now }
;

Person.^create:
    :name<Fernando>,
    :posts[
        {
            :title(“My new post”),
            :body(“A long post”)
        },
    ]
;

my $post = Post.^load: :title(“My new post”);

say $post.body;

my $author = $post.author;
$author.name = “John Doe”;

$author.^save;

$author.posts.create:
    :title(“Second post”),
    :body(“Another long post”),
;

$author.posts.elems;
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

