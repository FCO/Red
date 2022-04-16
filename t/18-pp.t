use Test;

plan :skip-all("Pg do not accept minus") with %*ENV<RED_DATABASE>;

use lib "t/lib";
use TestRed;

use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Zub, Foo).drop.create;

my $zub = Zub.^create;
my $one = $zub.foos.create( bar => "one" );
my $two = $zub.foos.create( bar => "two" );
$zub.default-foo = $one;
$zub.^save;

lives-ok { [ $one, $two ].perl }
done-testing;
