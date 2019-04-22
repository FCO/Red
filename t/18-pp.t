use Test;

use lib "t/lib";
use TestRed;

use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

Zub.^create-table;
Foo.^create-table;

my $zub = Zub.^create;
my $one = $zub.foos.create( bar => "one" );
my $two = $zub.foos.create( bar => "two" );
$zub.default-foo = $one;
$zub.^save;

lives-ok { [ $one, $two ].perl }
done-testing;
