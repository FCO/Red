use Test;
use Red;
model Bla {
    model Ble is table<bla_ble> {
        has UInt $!id   is serial;
        has Str  $.name is unique;
        has Bla  @.blas is relationship{ .ble-id };
    }

    has UInt $!id     is serial;
    has UInt $!ble-id is referencing( *.id, :model(Ble));
    has Ble  $.ble    is relationship{ .ble-id };
    has Str  $.name   is unique;
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Bla, Bla::Ble).drop.create;

Bla.^create: :name<bla1>, :ble{ :name<ble1> };
Bla::Ble.^create: :name<ble2>, :blas[
    { :name<bla2.1> },
    { :name<bla2.2> },
    { :name<bla2.3> },
    { :name<bla2.4> },
    { :name<bla2.5> },
];

is Bla.^all.sort(*.name).map(*.name).Seq, <
    bla1
    bla2.1
    bla2.2
    bla2.3
    bla2.4
    bla2.5
>;
is Bla::Ble.^all.sort(*.name).map(*.name).Seq, <ble1 ble2>;

is Bla.^find(:name<bla1>).ble.name, "ble1";
is Bla.^find(:name<bla2.1>).ble.name, "ble2";
is Bla.^find(:name<bla2.2>).ble.name, "ble2";
is Bla.^find(:name<bla2.3>).ble.name, "ble2";
is Bla.^find(:name<bla2.4>).ble.name, "ble2";
is Bla.^find(:name<bla2.5>).ble.name, "ble2";

is Bla::Ble.^find(:name<ble1>).blas.sort(*.name).map(*.name).Seq, <bla1>;
is Bla::Ble.^find(:name<ble2>).blas.sort(*.name).map(*.name).Seq, <
    bla2.1
    bla2.2
    bla2.3
    bla2.4
    bla2.5
>;

done-testing