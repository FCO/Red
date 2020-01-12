use Test;
use Red;

model Foo {
    has Int $.bar is serial;
    has Str $.foo is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

Foo.^create-table;

Foo.^create: foo => "test$_" for ^10;

is Foo.^all.pick(*).map(*.foo).Seq.sort, (^10).map: { "test$_" };

is Foo.^all.map(*.foo).pick(3).Seq.elems, 3;

isa-ok Foo.^all.map(*.foo).pick, Str;

done-testing
