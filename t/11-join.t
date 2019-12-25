use Red;
use Test;

model Bla {
    has Int $.id        is serial;
    has Int $.ble-id    is referencing(*.id, :model<Ble>);
    has     $.ble       is relationship(*.ble-id, :model<Ble>) is rw;
}

model Ble {
    has Int $.id    is id;
    has     @.bla   is relationship({ .ble-id }, :model<Bla>);
    has Int $.b     is column
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

Bla.^create-table;
Ble.^create-table;

Ble.^create(:1b).bla.create;
Ble.^create(:1b).bla.create;
Ble.^create(:1b).bla.create;

Ble.^create(:2b).bla.create;
Ble.^create(:3b).bla.create;
Ble.^create(:4b).bla.create;

is Bla.^all.grep({ .ble.b == 1 }).map(*.id), (1,2,3);

done-testing
