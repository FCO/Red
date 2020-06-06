use Test;
use Red;

model Bla {
    has Int $.a is column;
    has Int $.b is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

Bla.^create-table;

Bla.^create: :1a, :1b;
Bla.^create: :2a, :1b;
Bla.^create: :3a, :2b;
Bla.^create: :4a, :2b;
Bla.^create: :5a, :3b;
Bla.^create: :1a, :3b;
Bla.^create: :2a, :4b;
Bla.^create: :3a, :4b;
Bla.^create: :4a, :5b;
Bla.^create: :5a, :5b;

is Bla.^all.grep(*.a == 3).elems, 2;

is Bla.^all.grep({ .a == 1 && .b == 1}).elems, 1;
is Bla.^all.grep({ .a <= 5 && .b <= 5}).elems, 10;

done-testing;
