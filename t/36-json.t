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

is Bla.^all.map({ .num1<bla> }), 42;

Bla.^all.map({ .num1<ble> = 13 }).save;

is Bla.^all.map({ .num1<ble> }), 13;

Bla.^all.map({ .num1<bla> -= .num1<ble> }).save;

is Bla.^all.map({ .num1<bla> }), 29;

done-testing;
