use v6;
use Red::Do;
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
use Red::AST::Optimizer::AND;
use Red::AST::Optimizer::OR;
use Red::AST::Optimizer::Case;
use Red::Class;
use Red::DB;
use Red::Schema;
use Red::Formatter;
use Red::AST::Infixes;

class Red:ver<0.1.76>:api<2> {
    our %experimentals;
    our @experimental-roles;
    method events   { Red::Class.instance.events }
    method emit(|c) { get-RED-DB.emit: |c        }
    method experimentals { %experimentals }
    method ping {
        do for (%GLOBAL::RED-DEFAULT-DRIVERS || :default(get-RED-DB)).kv -> $key, $conn {
            $key => $conn.ping
        }.Map
    }
    method exports(@experimentals --> Map()) {
        %Red::experimentals{$_} = True for @experimentals;
        Red::Do::EXPORT::ALL::,
        Red::Traits::EXPORT::ALL::,
        Red::Operators::EXPORT::ALL::,
        Red::Schema::EXPORT::ALL::,
        ‘&database’ => &database,
        |@experimentals.map(-> $feature { |experimental( $feature ) })
    }
}

my %unsupported-raku-versions{Version} =
    v2022.06 => [
        "2022.06 has a bug that calls `iterator` method on instantiation of a class",
        "that does `Positional` and `Sequence` roles and have attributes with initialisation,",
        "making it impossible to use `Red::ResultSeq`. Please update your Raku to use Red.",
    ],
    v2024.03 => [
        "2024.03 has a bug that breaks ClassHOW does role. Please update your Raku to use Red.",
    ],
;

BEGIN {
    Red::Column.^add_role: Red::ColumnMethods;
    Red::Column.^compose;

    for <AND OR Case> -> $infix {
        ::("Red::AST::$infix").^add_role: ::("Red::AST::Optimizer::$infix");
        ::("Red::AST::$infix").^compose;
    }
}

my package EXPORTHOW {
    my $ver = $*RAKU.compiler.version;
    die "\o33[31;1m$ver\o33[m is \o33[1mnot\o33[m supported by \o33[31;1mRed\o33[m:\n" ~ .join("\n").indent: 8 with %unsupported-raku-versions{$ver};

    package DECLARE {
        constant model = MetamodelX::Red::Model;
    }
}

proto experimental(Str) {*}

multi experimental("shortname") {
    MetamodelX::Red::Model.^add_method: "experimental-name", method (\model) { model.^shortname }
    MetamodelX::Red::Model.^compose;
    Empty
}

multi experimental("formatters") {
    MetamodelX::Red::Model.^add_method: "experimental-formatter", method { True }
    Red::Column.^add_method: "experimental-formatter", method { True }
    MetamodelX::Red::Model.^compose;
    Red::Column.^compose;
    Empty
}

multi experimental($ where "experimental migrations" | "migrations") {
    require ::('MetamodelX::Red::Migration');
    @Red::experimental-roles.push: ::('MetamodelX::Red::Migration');

    Empty
}

multi experimental("supply") {
    require ::('MetamodelX::Red::Supply');
    @Red::experimental-roles.push: ::('MetamodelX::Red::Supply');

    Empty
}

multi experimental("is-handling") {
    multi trait_mod:<is>(Mu:U $model, :$handling) {
        for $handling<> {
            my ($orig, $new) = $_ ~~ Pair ?? [.key, .value] !! [$_, $_];
            $model.^add_method: $new, method (|c) { self.^all."$orig"(|c) }
        }
    }
    Map(
            '&trait_mod:<is>' => &trait_mod:<is>
    )
}

multi experimental("has-one") {
    Empty
}

multi experimental("refreshable") {
    require ::('MetamodelX::Red::Refreshable');
    @Red::experimental-roles.push: ::('MetamodelX::Red::Refreshable');

    Empty
}

multi experimental($feature) { die "Experimental feature '{ $feature }' not recognized." }

multi EXPORT(+@experimentals) {
	#my $no = "no-optimization";
    	#if @experimentals.none eq $no {
	#        require ::("Red::AST::Infixes");
    	#        for <AND OR Case> -> $infix {
	#		::("Red::AST::$infix").^add_role: ::("Red::AST::Optimizer::$infix");
	#		::("Red::AST::$infix").^compose;
    	#        }
    	#} else {
    	#        @experimentals .= grep: { $_ ne $no }
    	#}
    Red.exports(@experimentals)
}

=begin pod

[![Build Status](https://github.com/FCO/Red/workflows/test/badge.svg)](https://github.com/FCO/Red/actions)
[![Build Status](https://github.com/FCO/Red/workflows/ecosystem/badge.svg)](https://github.com/FCO/Red/actions)
[![SparrowCI](https://ci.sparrowhub.io/project/gh-FCO-Red/badge)](https://ci.sparrowhub.io)

=begin head1
Red
=end head1

Take a look at our Documentation: L<https://fco.github.io/Red/>

=head2 Red - A **WiP** ORM for Raku

=head2 INSTALL

Install with (you need **rakudo 2018.12-94-g495ac7c00** or **newer**):

    zef install Red

=head2 SYNOPSIS

=begin code :lang<raku>

use Red:api<2>;

model Person {...}

model Post is rw {
    has Int         $.id        is serial;
    has Int         $!author-id is referencing( *.id, :model(Person) );
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
    has Int  $.id            is serial;
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };
    method active-posts { @!posts.grep: not *.deleted }
}

my $*RED-DB = database "SQLite";

Person.^create-table;
=end code

=begin code :lang<sql>
-- Equivalent to the following query:
CREATE TABLE person(
    id integer NOT NULL primary key
    AUTOINCREMENT,
    name varchar(255) NOT NULL
)
=end code

=begin code :lang<raku>
Post.^create-table;
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
my Post $post1 = Post.^load: :42id;
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
my Post $post1 = Post.^load: 42;
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
my Post $post1 = Post.^load: :title("my title");
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
my $person = Person.^create: :name<Fernando>;
=end code

=begin code :lang<sql>
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    $1
) RETURNING *
-- BIND: ["Fernando"]
=end code

=begin code :lang<raku>
RETURNS:
Person.new(name => "Fernando")
=end code

=begin code :lang<raku>
say $person.posts;
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
say Person.new(:2id)
    .active-posts
    .grep: { .created > now }
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
my $now = now;
say Person.new(:3id)
    .active-posts
    .grep: { .created > $now }
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
Person.^create:
    :name<Fernando>,
    :posts[
        {
            :title("My new post"),
            :body("A long post")
        },
    ]
;
=end code

=begin code :lang<sql>
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    ?
) RETURNING *
-- BIND: ["Fernando"]

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
) RETURNING *
-- BIND: [
--   "2019-04-02T22:55:13.658596+01:00",
--   "My new post",
--   1,
--   "",
--   Bool::False,
--   "A long post"
-- ]
=end code

=begin code :lang<raku>
my $post = Post.^load: :title("My new post");
=end code

=begin code :lang<sql>
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
=end code

=begin code :lang<raku>
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
=end code

=begin code :lang<raku>
say $post.body;
=end code

=begin code :lang<raku>
PRINTS:
A long post
=end code

=begin code :lang<raku>
my $author = $post.author;
=end code

=begin code :lang<raku>
RETURNS:
Person.new(name => "Fernando")
=end code

=begin code :lang<raku>
$author.name = "John Doe";

$author.^save;
=end code

=begin code :lang<sql>
-- Equivalent to the following query:
UPDATE person SET
    name = ‘John Doe’
WHERE id = 1
=end code

=begin code :lang<raku>
$author.posts.create:
    :title("Second post"),
    :body("Another long post");
=end code

=begin code :lang<sql>
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
) RETURNING *
-- BIND: [
--   "Second post",
--   "Another long post",
--   "2019-04-02T23:28:09.346442+01:00",
--   "",
--   Bool::False,
--   1
-- ]
=end code

=begin code :lang<raku>
$author.posts.elems;
=end code

=begin code :lang<sql>
-- Equivalent to the following query:
SELECT
    count(*) as "data_1"
FROM
    post
WHERE
    post.author_id = ?
-- BIND: [1]
=end code

=begin code :lang<raku>
RETURNS:
2
=end code

=head2 DESCRIPTION

Red is a *WiP* ORM for Raku.

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

=begin code :lang<raku>
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
=end code

If you want to put your schema into multiple files, you can create an "indirect"
relationship, and Red will look up the related models as necessary.

=begin code :lang<raku>
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

=begin code :lang<raku>
    has Int     $!related-id is referencing{ :model<Related>, :column<id>,
                                             :require<MyApp::Schema::Related> };
=end code

=head4 custom table name

=begin code :lang<raku>

model MyModel is table<custom_table_name> {}

=end code

=head4 not nullable columns by default

Red, by default, has not nullable columns, to change it:

=begin code :lang<raku>
#| This makes this model’s columns nullable by default
model MyModel is nullable {
    has Int $.col1 is column;               #= this column is nullable
    has Int $.col2 is column{ :!nullable }; #= this one is not nullable
}
=end code

=head4 load object from database

=begin code :lang<raku>
MyModel.^load: 42;
MyModel.^load: id => 42;
=end code

=head4 save object on the database

=begin code :lang<raku>
$object.^save;
=end code

=head4 search for a list of object

=begin code :lang<raku>
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

=begin code :lang<raku>
model Bla is temp { ... }
=end code

=head4 Create table

=begin code :lang<raku>
Question.^create-table;
Question.^create-table: :if-not-exists;
Question.^create-table: :unless-exists;
=end code

=head4 IN

=begin code :lang<raku>
Question.^all.grep: *.answer ⊂ (3.14, 13, 42)
=end code

=head4 create

=begin code :lang<raku>

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
