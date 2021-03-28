use Test;
use Red;
use lib $?FILE.IO.parent(1).add('lib');

use tomgraceysSchema;

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

todo "Add a way to accept type objects instead of strings on :model";
lives-ok {
	schema(User, Vmail).create;
	isa-ok User.^create( username => "Bill" ), User;
}

done-testing;
