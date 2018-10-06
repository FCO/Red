#!/usr/bin/env perl6

use v6;

use lib <lib ../../lib>;
use Red;

model Person {...}

model Post is rw {
    has Int     $.id        is serial;
    has Int     $!author-id is referencing{ Person.id };
    has Str     $.title     is column{ :unique };
    has Str     $.body      is column;
    has Person  $.author    is relationship{ .author-id };
    has Bool    $.deleted   is column = False;
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
my $post = $p.posts.create: :title<Bla>, :body<BlaBle1>;

$p.posts.create: :title<Ble>, :body<BlaBle2>;

say "✓ Available post title(s) →\n\t", $p.posts.map: *.title;

say "✘ Deleting Post";
$post.delete;

say "✓ Available post id(s) →\n\t", $p.active-posts.map: *.id;

