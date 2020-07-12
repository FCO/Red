use Test;

use Red:api<2>;

use lib <t/lib>;
use Sentence;
use Link;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Sentence, Link).create;

Sentence.^populate;
Link.^populate;

is Sentence.translate("Hello", :to<pt>)          .sentence, "Ola";
is Sentence.translate("Hello", :to<esp>)         .sentence, "Hola";
is Sentence.translate("Ola", :from<pt>, :to<esp>).sentence, "Hola";

my @portuguese = Sentence.^all.grep: *.lang eq "pt";
is @portuguese.first(*.sentence eq "Ola").translate(:to<eng>).sentence, "Hello";

done-testing;
