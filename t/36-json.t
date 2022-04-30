use Test;
use Red;
use Red::Type::Json;

plan 6;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model Bla {
    has UInt $!id is serial;
    has Json $.num1 is rw is column;
}

schema(Bla).drop;

Bla.^create-table;
Bla.^create: :num1{:42bla};
is Bla.^all.map({ .num1<bla> }).head, 42;

if $driver eq "Pg" {
    skip-rest "Pg not accepting update on json yet";
    exit
}

# TODO: use jsonb_set for Pg
Bla.^all.map({ .num1<ble> = 13 }).save;
is Bla.^all.map({ .num1<ble> }).head, 13;

Bla.^all.map({ .num1<bla> -= .num1<ble> }).save;
is Bla.^all.map({ .num1<bla> }).head, 29;

Bla.^all.map({ .num1<bli> = {:blo(3.14)} }).save;
is Bla.^all.map({ .num1<bli><blo> }).head, 3.14;

Bla.^all.map({ .num1 = {:blu[1, 2, 3]} }).save;
is-deeply Bla.^all.map({ .num1<blu> }).head, [1, 2, 3];

Bla.^all.map({ .num1<ble>:delete }).save;
is Bla.^all.map({ .num1<ble> }).head, Json;
