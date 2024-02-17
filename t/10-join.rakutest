use Red;
use Test;

model Bla {
    has Int $.id        is serial;
    has Int $.ble-id    is referencing(*.id, :model<Ble>);
    has     $.ble       is relationship(*.ble-id, :model<Ble>) is rw;
}

model Ble {
    has Int $.id    is serial;
    has     @.bla   is relationship({ .ble-id }, :model<Bla>);
    has Int $.b     is column
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Bla, Ble).drop.create;

Ble.^create(:1b).bla.create;
Ble.^create(:1b).bla.create;
Ble.^create(:1b).bla.create;

Ble.^create(:2b).bla.create;
Ble.^create(:3b).bla.create;
Ble.^create(:4b).bla.create;

is Bla.^all.grep({ .ble.b == 1 }).map(*.id), (1,2,3);

done-testing
