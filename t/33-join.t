use Test;
use Red;

my $*RED-FALLBACK       = False;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model Bla { has UInt $!id is serial; has Int $.ble is column }
model Ble { has UInt $!id is serial; has Int $.bla is column }

schema(Bla, Ble).drop.create;

Bla.^create: :ble($_) for ^10;
Ble.^create: :bla($_) for ^10;

is Bla.^all.grep({ .^join(Ble, *.ble == *.bla).bla == 3 }).Seq>>.ble, < 3 >;

is Bla.^join(Ble, *.ble == *.bla).^all.map(*.bla), ^10;

is Bla.^join(:name<test>, Ble, *.ble == *.bla).^all.map(*.bla), ^10;

without %*ENV<RED_DATABASE> {
    is Bla.^all.grep(*.ble %% 2).join-model(Ble, *.ble / 2 == *.bla).map(*.bla), ^5; # TODO
}

done-testing;
