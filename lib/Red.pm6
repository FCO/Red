use v6;
use Red::Model;
use Red::Attr::Column;
use Red::Column;
use Red::ColumnMethods;
use Red::Utils;
use Red::ResultSeq;
use Red::DefaultResultSeq;
use Red::Attr::Query;
use Red::AST;
use MetamodelX::Red::Model;
use Red::Traits;
use Red::Operators;
use Red::Database;

class Red:ver<0.0.1>:api<0> {}

BEGIN {
    Red::Column.^add_role: Red::ColumnMethods;
    Red::Column.^compose;
}

my package EXPORTHOW {
    package DECLARE {
        constant model = MetamodelX::Red::Model;
    }
}

sub EXPORT {
    return %(
        Red::Traits::EXPORT::ALL::,
        Red::Operators::EXPORT::ALL::,
        '&database' => &database,
    );
}

=begin pod

=begin head1
Red
=end head1

Take a look at our Wiki: L<https://github.com/FCO/Red/wiki>

=head2 Red - A **WiP** ORM for perl6

=head2 INSTALL

Install with (you need **rakudo 2018.12-94-g495ac7c00** or **newer**):

    zef install Red

=head2 SYNOPSIS

    use Red;

    model Person { ... }

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



=head2 DESCRIPTION

Red is a *WiP* ORM for perl6. It's not working yet. My objective publishing is only ask for help validating the APIs.

=head3 traits

=item C<is column>
=item C<is column{}>
=item C<is id>
=item C<is id{}>
=item C<is serial>
=item C<is referencing{}>
=item C<is relationship{}>
=item C<is table<>>
=item C<is nullable>

=head3 features:

=head4 custom table name

    model MyModel is table<custom_table_name> {}

=head4 not nullable columns by default

Red, by default, has not nullable columns, to change it:

    model MyModel is nullable {                 # is nullable makes this model's columns nullable by default
        has Int $.col1 is column;               # this column now is nullable
        has Int $.col2 is column{ :!nullable }; # this column is not nullable
    }

=head4 load object from database

    MyModel.^load: 42;
    MyModel.^load: id => 42;

=head4 save object on the database

    $object.^save;

=head4 search for a list of object

    Question.^all.grep: { .answer == 42 }; # returns a result seq

=head2 AUTHOR

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

=head2 COPYRIGHT AND LICENSE

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
