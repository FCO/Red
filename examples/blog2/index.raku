#!/usr/bin/env perl6

use v6;

use lib <lib examples/blog2>;
use Red;

use Person;
use Post;

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

.say for Post.^all.map: *.author.name