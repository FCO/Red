use Test;
use Red;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;
enum Bla <a e i o u>;

model TestModel {
    has $.id is serial;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(TestModel).drop;
TestModel.^create-table;

dies-ok {
    TestModel.new.^create
}, "Dies if call .^create on a defined object";

lives-ok {
    TestModel.^create
}, "Continue working for calling it on type object";

done-testing;
