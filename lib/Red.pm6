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
use Red::AST::Infixes;
use Red::AST::Optimizer::AND;
use Red::AST::Optimizer::OR;
use Red::AST::Optimizer::Case;

class Red:ver<0.0.4>:api<1> {}

BEGIN {
    Red::Column.^add_role: Red::ColumnMethods;
    Red::Column.^compose;

    for <AND OR Case> -> $infix {
        ::(“Red::AST::$infix”).^add_role: ::(“Red::AST::Optimizer::$infix”);
        ::(“Red::AST::$infix”).^compose;
    }
}

my package EXPORTHOW {
    package DECLARE {
        constant model = MetamodelX::Red::Model;
    }
}

multi EXPORT(“red-do”) {
    use Red::Do;

    Map(
        Red::Do::EXPORT::ALL::,
        Red::Traits::EXPORT::ALL::,
        Red::Operators::EXPORT::ALL::,
        ‘&database’ => &database,
    )
}

multi EXPORT(“experimental migrations”) {
    use MetamodelX::Red::Migration;
    MetamodelX::Red::Model.^add_role: MetamodelX::Red::Migration;
    MetamodelX::Red::Model.^compose;

    Map(
        Red::Traits::EXPORT::ALL::,
        Red::Operators::EXPORT::ALL::,
        ‘&database’ => &database,
    )
}

multi EXPORT {
    Map(
        Red::Traits::EXPORT::ALL::,
        Red::Operators::EXPORT::ALL::,
        ‘&database’ => &database,
    )
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

=begin code :lang<perl6>

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
=end code

=head2 DESCRIPTION

Red is a *WiP* ORM for perl6. It’s not working yet. My objective publishing is only ask for help validating the APIs.

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

=head4 relationships

Red will infer relationship data if you use type constraints on your properties.

=begin code :lang<perl6>
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
=end code

If you want to put your schema into multiple files, you can create an “indirect”
relationship, and Red will look up the related models as necessary.

=begin code :lang<perl6>
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
=end code

If Red can’t find where your C<model> is defined you can override where it looks
with C<require>:

=begin code :lang<perl6>
    has Int     $!related-id is referencing{ :model<Related>, :column<id>,
                                             :require<MyApp::Schema::Related> };
=end code

=head4 custom table name

=begin code :lang<perl6>

model MyModel is table<custom_table_name> {}

=end code

=head4 not nullable columns by default

Red, by default, has not nullable columns, to change it:

=begin code :lang<perl6>

#| This makes this model’s columns nullable by default
model MyModel is nullable {
    has Int $.col1 is column;               #= this column is nullable
    has Int $.col2 is column{ :!nullable }; #= this one is not nullable
}

=end code

=head4 load object from database

=begin code :lang<perl6>

MyModel.^load: 42;
MyModel.^load: id => 42;

=end code

=head4 save object on the database

=begin code :lang<perl6>

$object.^save;

=end code

=head4 search for a list of object

=begin code :lang<perl6>

Question.^all.grep: { .answer == 42 }; # returns a result seq

=end code

=head4 phasers

=item C<before-create>
=item C<after-create>
=item C<before-update>
=item C<after-update>
=item C<before-delete>
=item C<after-delete>

=head4 Temporary table

=begin code :lang<perl6>

model Bla is temp { ... }

=end code

=head4 Create table

=begin code :lang<perl6>

Question.^create-table;
Question.^create-table: :if-not-exists;
Question.^create-table: :unless-exists;

=end code

=head4 IN

=begin code :lang<perl6>

Question.^all.grep: *.answer ⊂ (3.14, 13, 42)

=end code

=head4 create

=begin code :lanf<perl6>

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

=end code

=head2 AUTHOR

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

=head2 COPYRIGHT AND LICENSE

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
