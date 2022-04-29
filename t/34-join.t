use Test;
use Red;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model Bla { ... }
model Ble { ... }


model Bla {
    has UInt $.id     is serial;
    has      @.ble    is relationship( *.bla-id, :model<Ble> );
}

model Ble {
    has UInt $.id     is serial;
    has UInt $.bla-id is referencing( *.id, :model<Bla> );
    has Int  $.value  is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Bla, Ble).drop.create;

Bla.^create: :ble[{ :1value }, { :2value }, { :3value }];

is Bla.^join(Ble, *.id == *.bla-id).^all.Seq.map(*.value), <1 2 3>;
done-testing;
