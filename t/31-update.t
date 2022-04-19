use Test;
use Red;
plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model Bla {
    has Int $!id   is serial;
    has Int $.num1 is rw is column;
    has Int $.num2 is rw is column;
}

model Ble is rw {
    has Int $!id     is serial;
    has Int $.a      is column;
    has Int $!bla-id is referencing(*.id, :model(Bla));
    has     $.bla    is relationship(*.bla-id, :model(Bla));
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Bla, Ble).drop;
Bla.^create-table;
Ble.^create-table;

Bla.^create: :41num1, :13num2;

Bla.^all.map({ .num1 += 1 }).save;
is Bla.^all.head.num1, 42;

Bla.^all.map({ .num1 -= 29 }).save;
is Bla.^all.head.num1, 13;

Bla.^all.grep(*.num2 == 13).map({ .num1 /= .num2 }).save;
is Bla.^all.head.num1, 1;

# TODO: Remove the quietly
quietly Bla.^all.map({ .num1 *= .num2; .num2 = 42 }).save;
is Bla.^all.head.num1, 13;
is Bla.^all.head.num2, 42;

Ble.^create: :a($_), :bla(%( :num1($_), :num2($_ * 2) )) for ^10;

# TODO: Remove the quietly
quietly Ble.^all.grep({ .bla.num1 + .bla.num2 <= 15 }).map({ .a *= 10 }).save;

is Ble.^all.map(*.a).Seq, < 0 10 20 30 40 50 6 7 8 9 >;

# TODO: Remove the quietly
quietly Ble.^all.grep({ .bla.num1 + .bla.num2 <= 15 && .a %% 20 }).map({ .a += 1 }).save;

is Ble.^all.map(*.a).Seq, < 1 10 21 30 41 50 6 7 8 9 >;

done-testing;
