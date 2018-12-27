use v6;

# This is the same as the 04-blog.t except it exercises the
# alternative relation trait style
use Test;

use Red;

model Post is rw {
    has Int         $.id        is serial;
    has Int         $.author-id is referencing(model => 'Person', column => 'id' );
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has             $.author    is relationship({ .author-id }, model => 'Person');
}

model Person is rw {
    has Int  $.id            is serial;
    has Str  $.name          is column;
    has      @.posts         is relationship({ .author-id }, model => 'Post');
}


my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

lives-ok { Person.^create-table }, "create table for Person";
lives-ok { Post.^create-table }, "create table for Post";

my $p;
lives-ok { $p = Person.^create: :name<Fernando> }, "Create a Person";
isa-ok $p, Person;
is $p.name, "Fernando", "and it is the person we expected";
ok $p.id.defined, "primary key is defined";;
is $p.id, 1, "and it is the value we expected";

my $post;
lives-ok {
    $post = $p.posts.create: :title("Red's commit"), :body("Merge branch 'master' of https://github.com/FCO/Red") ;
}, "create a related post";
isa-ok $post, Post;
is $post.author-id, $p.id, "and the author-id of the post is the one we expected";
is $post.author.name, $p.name, "author name is correct";
is $post.title, "Red's commit", "post title is correct";
is $post.body, "Merge branch 'master' of https://github.com/FCO/Red", "post body is correct";

my $post2;
lives-ok { $post2 = $p.posts.grep( *.id == $post.id).head }, "retrieve post by query";

is $post2.id, $post.id, "got the right post back";
is $post2.author.name, $p.name, "retrieve author";


done-testing
