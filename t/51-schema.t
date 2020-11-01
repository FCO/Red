use Test;
use Red;
use Red::Schema;
use lib "t/lib";

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

my $s1 = schema <Post Person>;
$s1.drop;

isa-ok $s1, Red::Schema;
is $s1.Post.^name, "Post";
is $s1.Person.^name, "Person";

isa-ok (my $bla = $s1.Bla), Failure;

my $s2 = schema($s1.Post, $s1.Person);
#$s2.drop;

isa-ok $s2, Red::Schema;
is $s2.Post.^name, "Post";
is $s2.Person.^name, "Person";

isa-ok (my $ble = $s2.Ble), Failure;

is $s1.Post, $s2.Post;
is $s1.Person, $s2.Person;

my $defang-failures = ?$bla && ?$ble;

lives-ok {
    $s1.create;
    is $s1.Post.^all.Seq, ();
    $s1.drop
}

dies-ok {
    is $s1.Post.^all.Seq, ();
}

done-testing;
