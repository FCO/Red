use Test;
use Red:api<2>;

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


red-defaults default => database "SQLite";
my $*RED-DEBUG = ?%*ENV<RED_DEBUG>;

AAA.^create-table; BBB.^create-table;

my $a = AAA.^create: :42id1, :13id2;
$a.many.create: :value($_) for ^10;

is-deeply $a.many.Seq, BBB.new(:value($++)) xx 10;
is-deeply $a.many.head.a, $a;

done-testing;
