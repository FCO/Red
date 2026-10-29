use Test;
use Red:api<2>;

model Bla {
    has $!id    is serial;
    has $.value is column;
    has @.bles  is relationship( *.bla-id, :model<Ble> );
}

model Ble {
    has $!id     is serial;
    has $.value  is column;
    has $!bla-id is referencing( *.id, :model<Bla> );
    has $.bla    is relationship( *.bla-id, :model<Bla> )
}

#start react whenever Red.events {
#    .say
#}
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
red-defaults default    => database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

red-defaults default => database "SQLite";

Bla.^create-table; Ble.^create-table;


for ^10 -> $value {
    given Bla.^create: :$value {
        .bles.create(:value($value + (++$ / 10))) xx 10
    }
}

start react whenever Red.events {
    flunk "Did not prefetch" if $++
}
isa-ok .bla, Bla for Ble.^all;

pass "Prefetched";

done-testing;
