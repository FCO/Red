use v6;
use Test;

use Red;

model Person {...}

model Post is rw {
    has Int         $.id        is serial;
    has Int         $.author-id is referencing{ Person.id };
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has Person      $.author    is relationship{ .author-id };
    has Bool        $.deleted   is column = False;
    has DateTime    $.created   is column .= now;
    has Set         $.tags      is column{
        :type<string>,
        :deflate{ .keys.join: "," },
        :inflate{ set(.split: ",") }
    };
    method delete { $!deleted = True; self.^save }
}

model Person is rw {
    has Int  $.id            is serial;
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };
    method active-posts { @!posts.grep: not *.deleted }
}

my $*RED-DEBUG = $_ with %*ENV<RED-DEBUG>;
my $*RED-DB = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

lives-ok { Person.^create-table }
lives-ok { Post.^create-table }

my $p;
lives-ok { $p = Person.^create: :name<Fernando> }
isa-ok $p, Person;
is $p.name, "Fernando";
ok $p.id.defined;
is $p.id, 1;

my $post;
lives-ok { $post = $p.posts.create: :title("Red's commit"), :body("Merge branch 'master' of https://github.com/FCO/Red") }
isa-ok $post, Post;
is $post.author-id, $p.id;
is $post.title, "Red's commit";
is $post.body, "Merge branch 'master' of https://github.com/FCO/Red";

my $post2;
lives-ok { $post2 = $p.posts.create: :title("Another commit"), :body("Blablabla"), :tags(set <bla ble>) }
is $post2.author-id, $p.id;
is $post2.title, "Another commit";
is $post2.body, "Blablabla";
todo "NYI: use the custom inflator creating the user";
ok $post2.tags ~~ set <bla ble>;

lives-ok { $post.^delete }
ok not Post.^load($post.id).defined;
todo "NYI";
isa-ok Post.^load($post.id), Post;

is $p.active-posts.map(*.id), (2);

isa-ok $p.posts.head.created, DateTime;

ok $p.posts.map(*.tags).head ~~ set <bla ble>;

done-testing
