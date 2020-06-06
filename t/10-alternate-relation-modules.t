use v6;

# This is the same as the t/09-alternate-relation.t
# except the model classes are in separate modules
# this is to discover precomp issues.

use Test;

use Red;

use lib <t/lib>;

use Person;
use Post;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

lives-ok { schema(Person, Post).create }, "create table for Person and Post";

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
