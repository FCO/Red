WiP
===

NAME
====

Red - A *WiP* ORM for perl6

SYNOPSIS
========

```perl6
use Red;

model Person {...}

model Post {
    has Int     $.id        is column{ :id };
    has Int     $.author-id is column{ :references{ Person.id } };
    has Person  $.author    = .^relates: { .id == $!author-id };
    has Bool    $.deleted   is column = False;
    has Instant $.created   is column = now;
}

model Person {
    has Int             $.id            is column{ :id };
    has Str             $.name          is column;
    has Post::ResultSeq $.posts         = .^relates: { .author-id == $!id };
    has Post::ResultSeq $.active-posts  = .^relates: { .author-id == $!id AND not .deleted }
}

my $*REDDB = database 'postgres', :host<localhost>; 

my Post $post1 = Post.^load: :42id;  # Returns a Post object with data returned by
                                     # SELECT * FROM post me WHERE id = 42
my $id = 13;
my Post $post2 = Post.^load: :$id;  # Returns a Post object with data returned by
                                     # SELECT * FROM post me WHERE id = ? with [13] as bind

say $post2.author;  # Prints a Person object with data returned by
                    # SELECT * FROM person me WHERE me.id = ?

say Person.new(:1id).posts; # Prints a Seq (Post::ResultSeq) with
                            # the return of:
                            # SELECT * FROM post me WHERE me.author_id = ?
                            # with [1] as bind.
                            # converted for Post objects

say Person.new(:2id)
    .active-posts
    .where: { .created > Date.today }   # SELECT * FROM post me WHERE
;                                       # me.author_id = ? AND me.deleted = 't'
datetime
                                        # AND me.created > '2018-08-14'::datetime
                                        # with [2] as bind.

my $author = $post2.author;
$author.name = "John Doe";
$author.^save;
```

DESCRIPTION
===========

Red is a *WiP* ORM for perl6. It's not working yet. My objective publishing is only ask for help validating the APIs.

## traits:

* `is column`
* `is column{}`
* `is referencing`
* `is rs-class()`
* `is rs-class<>`
* `is table<>`

AUTHOR
======

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

