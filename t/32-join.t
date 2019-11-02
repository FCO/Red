use Test;
use Red;

model Bla { ... }
model Ble { ... }
model Bli { ... }

model Bla {
    has UInt $.id     is serial;
    has UInt $.ble-id is referencing( *.id, :model<Ble>);
    has      $.ble    is relationship( *.ble-id, :model<Ble> );
}

model Ble {
    has UInt $.id     is serial;
    has UInt $.bli-id is referencing( *.id, :model<Bli> );
    has      $.bli    is relationship( *.bli-id, :model<Bli> );
}

model Bli {
    has UInt $.id    is serial;
    has Int  $.value is column;
}

my $*RED-DEBUG = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB    = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

Bla.^create-table; Ble.^create-table; Bli.^create-table;

#Bla.^create: :ble{ :bli{ :1value } };
#Bla.^create: :ble{ :bli{ :2value } };
#Bla.^create: :ble{ :bli{ :3value } };

my $bli1 = Bli.^create: :1value;
my $ble1 = Ble.^create: :bli-id($bli1.id);
my $bla1 = Bla.^create: :ble-id($ble1.id);

my $bli2 = Bli.^create: :2value;
my $ble2 = Ble.^create: :bli-id($bli2.id);
my $bla2 = Bla.^create: :ble-id($ble2.id);

my $bli3 = Bli.^create: :3value;
my $ble3 = Ble.^create: :bli-id($bli3.id);
my $bla3 = Bla.^create: :ble-id($ble3.id);

is Bla.^all.grep({ .ble.bli.value == 1 }).map(*.ble.bli.value).Seq, <1>;
is Bla.^all.grep({ .ble.bli.value > 1 }).map(*.ble.bli.value).Seq, <2 3>;

done-testing;
