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
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Foo).drop;
Foo.^create-table;

is ?Foo.^all, False;

Foo.^create: foo => "babaa";

is ?Foo.^all, True;

done-testing
