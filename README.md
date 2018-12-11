[![Build Status](https://travis-ci.org/FCO/Red.svg?branch=master)](https://travis-ci.org/FCO/Red)


WiP
===

Take a look at our Wiki: <https://github.com/FCO/Red/wiki>

NAME
====

Red - A **WiP** ORM for raku

INSTALL
=======

It's not published yet, so you'll have to clone the repo:

```
git clone https://github.com/FCO/Red.git
```

install it's dependencies

```
zef install . --deps-only
```

once cloned, you can run it with `-Ilib` on the repo's root:


```
perl6 -Ilib examples/blog/index.p6
```


```
perl6 -Ilib -MRed -e 'your code here'
```

```
perl6 -Ilib t/02-tdd.t # this runs 1 test file
```

or you can run the tests with

```
zef test .
```

or install it with

```
zef install .
```

SYNOPSIS
========

```perl6
use Red;

model Person {...}

model Post {
    has Int     $.id        is id;
    has Int     $!author-id is referencing{ Person.id };
    has Str     $.title     is unique;
    has Str     $.body      is column;
    has Person  $.author    is relationship{ .author-id };
    has Bool    $.deleted   is column is rw = False;
    has Instant $.created   is column = now;

    method delete {
        $!deleted = True;
        self.^save
    }
}

model Person {
    has Int  $.id            is id;
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };

    method active-posts { @!posts.grep: { not .deleted } }
}

my $*REDDB = database 'Pg';

my Post $post1 = Post.^load: :42id;   # Returns a Post object with data returned by
                                      # SELECT * FROM post me WHERE me.id = 42
my $id = 13;
my Post $post2 = Post.^load: :$id;    # Returns a Post object with data returned by
                                      # SELECT * FROM post me WHERE me.id = ? with
                                      # [13] as bind

say $post2.author;                    # Prints a Person object with data returned by
                                      # SELECT * FROM person me WHERE me.id = ?

say Person.new(:1id).posts;           # Prints a Seq (Post::ResultSeq) with
                                      # the return of:
                                      # SELECT * FROM post me WHERE me.author_id = ?
                                      # with [1] as bind.
                                      # converted for Post objects

say Person.new(:2id)
    .active-posts
    .grep: { .created > Date.today }  # SELECT * FROM post me WHERE
;                                     # me.author_id = ? AND me.deleted = 't'
                                      # AND me.created > '2018-08-14'::datetime
                                      # with [2] as bind.

my $author = $post2.author;
$author.name = "John Doe";

$author.^save;                        # UPDATE person SET name = ?
                                      # WHERE id = ? with ['John Doe', 13] as bind

$author.posts.elems;                  # SELECT COUNT(*) FROM post
                                      # WHERE author_id = ?

my $p = $author.posts.create:         # INSERT INTO post(author_id, title, body, deleted, created)
    :title<Bla>,                      # VALUES(?, ?, ?, ?, ?)
    :body<body>
;


```

DESCRIPTION
===========

Red is a *WiP* ORM for perl6. It's not working yet. My objective publishing is only ask for help validating the APIs.

## traits:

* `is column`
* `is column{}`
* `is id`
* `is id{}`
* `is serial`
* `is referencing{}`
* `is relationship{}`
* `is rs-class()`
* `is rs-class<>`
* `is table<>`
* `is nullable`

## features:

### custom table name

```perl6
model MyModel is table<custom_table_name> {}
```

### not nullable columns by default

Red, by default, has not nullable columns, to change it:

```perl6
model MyModel is nullable {                 # is nullable makes this model's columns nullable by default
    has Int $.col1 is column;               # this column now is nullable
    has Int $.col2 is column{ :!nullable }; # this column is not nullable
}
```

### custom result seq class

```perl6
class CustomResultSeq does Red::ResultSeq {}

model AnotherModel is rs-class(CustomResultSeq) {}
```

### load object from database

```perl6
MyModel.^load: 42;
MyModel.^load: id => 42;
```

### save object on the database

```perl6
$object.^save;
```

### search for a list of object

```perl6
Question.^all.grep: { .answer == 42 }; # returns a result seq
```

AUTHOR
======

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

