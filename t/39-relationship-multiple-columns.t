use Test;
use Red:api<2>;

# TODO: Fix Fk with multiple columns for Pg
plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model AAA {
    has UInt $!id1 is id;
    has UInt $!id2 is id;
    has @.many     is relationship({ .a-id1, .a-id2 }, :model<BBB> );
}

model BBB {
    has UInt $!id     is serial;
    has UInt $!a-id1  is referencing( *.id1, :model<AAA> );
    has UInt $!a-id2  is referencing( *.id2, :model<AAA> );
    has $.a           is relationship({ .a-id1, .a-id2 }, :model<AAA> );
    has Int  $.value  is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
red-defaults default    => database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(AAA, BBB).drop.create;

my $a = AAA.^create: :42id1, :13id2;
$a.many.create: :value($_) for ^10;

is-deeply $a.many.Seq, BBB.new(:value($++)) xx 10;
is-deeply $a.many.head.a, $a;

done-testing;
