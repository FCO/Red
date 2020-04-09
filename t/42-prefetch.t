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
my $*RED-DEBUG          = ?%*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = ?%*ENV<RED_DEBUG_RESPONSE>;

red-defaults default => database "SQLite";

Bla.^create-table; Ble.^create-table;


for ^10 -> $value {
    given Bla.^create: :$value {
        .bles.create(:value($value + (++$ / 10))) xx 10
    }
}

.bla.say for Ble.^all;

done-testing;
