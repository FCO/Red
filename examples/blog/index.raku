#!/usr/bin/env perl6

use v6;

use lib <lib ../../lib>;
use Red;

model Person {...}

model Post is rw {
    has Int         $.id        is serial;
    has Int         $!author-id is referencing( *.id, :model<Person> );
    has Str         $.title     is unique;
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

my $*RED-DEBUG = True;
my $*RED-DB = database("SQLite");

say "✓ Creating tables for Person and Post";
Person.^create-table;
Post.^create-table;

say "✓ Creating a Person";
my $p  = Person.^create: :name<Fernando>;

say "✓ Creating a blog Post";
my $post = $p.posts.create: :title("Red's commit"), :body("Merge branch 'master' of https://github.com/FCO/Red");

$p.posts.create: :title("Another commit"), :body("Blablabla"), :tags(set <bla ble>);

say "✓ Available post title(s) → ", $p.posts.map: *.title;

say "✘ Deleting Post";
$post.delete;

say "✓ Available post id(s) → ", $p.active-posts.map: *.id;

say "✓ Date Inflated → ", $p.posts.head.created.^name;

say "✓ Data with custom inflator → ", $p.posts.map: *.tags;
