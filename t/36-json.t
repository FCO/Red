use Test;
use Red;
use Red::Type::Json;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);


model Bla {
    has $!id is serial;
    has Json $.num1 is rw is column;
}

Bla.^create-table;
Bla.^create: :num1{:42bla};
is Bla.^all.map({ .num1<bla> }).head, 42;

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

done-testing;
