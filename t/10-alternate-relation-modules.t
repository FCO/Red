use v6;

# This is the same as the t/09-alternate-relation.t
# except the model classes are in separate modules
# this is to discover precomp issues.

use Test;

# TODO: Fix it! why it breaks when using Red?
#use Red;
use Red::Database;

use lib <t/lib>;

use Person;
use Post;


my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

lives-ok { Person.^create-table }, "create table for Person";
lives-ok { Post.^create-table }, "create table for Post";

my $p;
$p = Person.^create: :name<Fernando>;
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
is $post.title, "Red's commit", "post title is correct";
is $post.body, "Merge branch 'master' of https://github.com/FCO/Red", "post body is correct";

done-testing
