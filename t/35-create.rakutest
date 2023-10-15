use Test;
use Red <has-one>;

model Bla {
    has UInt $.id      is serial;
    has Str  $.value   is column;
    has      @.bles    is relationship(*.bla-id, :model<Ble>);
    has      $.one-ble is relationship(*.bla-id, :model<Ble>, :has-one);
}

model Ble {
    has UInt $.id     is serial;
    has Str  $.value  is column;
    has UInt $.bla-id is referencing(*.id, :model<Bla>);
    has      $.bla    is relationship(*.bla-id, :model<Bla>);
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Bla, Ble).drop.create;

subtest "Simple create and fk id", {
    my $bla = Bla.^create: :value<test1>;
    my $ble = Ble.^create: :value<test2>, :bla-id($bla.id);

    isa-ok    $bla,               Bla;
    is-deeply $bla,               Bla.^load: $bla.id;
    isa-ok    $ble,               Ble;
    is-deeply $ble,               Ble.^load: $ble.id;
    is-deeply $ble.bla,           $bla;
    does-ok   $ble.bla.bles,      Red::ResultSeq;
    isa-ok    $ble.bla.bles,      Ble::ResultSeq;
    is-deeply $ble.bla.bles.head, $ble;
};

subtest "Simple create and using obj as fk", {
    my $bla = Bla.^create: :value<test1>;
    my $ble = Ble.^create: :value<test2>, :$bla;

    isa-ok    $bla,               Bla;
    is-deeply $bla,               Bla.^load: $bla.id;
    isa-ok    $ble,               Ble;
    is-deeply $ble,               Ble.^load: $ble.id;
    is-deeply $ble.bla,           $bla;
    does-ok   $ble.bla.bles,      Red::ResultSeq;
    isa-ok    $ble.bla.bles,      Ble::ResultSeq;
    is-deeply $ble.bla.bles.head, $ble;
};

subtest "Simple create and finding existing obj", {
    my $bla = Bla.^create: :value<test1>;
    my $ble = Ble.^create: :value<test2>, :bla{ :id($bla.id) };

    isa-ok    $bla,               Bla;
    is-deeply $bla,               Bla.^load: $bla.id;
    isa-ok    $ble,               Ble;
    is-deeply $ble,               Ble.^load: $ble.id;
    is-deeply $ble.bla,           $bla;
    does-ok   $ble.bla.bles,      Red::ResultSeq;
    isa-ok    $ble.bla.bles,      Ble::ResultSeq;
    is-deeply $ble.bla.bles.head, $ble;
};

subtest "Simple create and calling create on Relationship", {
    my $bla = Bla.^create: :value<test1>;
    $bla.bles.create(:value("test")) xx 3;

    isa-ok    $bla,                         Bla;
    is-deeply $bla,                         Bla.^load: $bla.id;

    does-ok   $bla.bles,                    Red::ResultSeq;
    isa-ok    $bla.bles,                    Ble::ResultSeq;
    is        $bla.bles.map(*.value),       <test test test>;
};

subtest "Simple create and creating by array", {
    my $bla = Bla.^create: :value<test1>, :bles[{:value<test3>}, {:value<test4>}];

    isa-ok    $bla,                         Bla;
    is-deeply $bla,                         Bla.^load: $bla.id;

    does-ok   $bla.bles,                    Red::ResultSeq;
    isa-ok    $bla.bles,                    Ble::ResultSeq;
    is        $bla.bles.map(*.value),       <test3 test4>;
};

subtest "Create with has-one", {
    my $bla = Bla.^create: :value<test1>, :one-ble{:value<test42>};

    isa-ok    $bla,                         Bla;
    is-deeply $bla,                         Bla.^load: $bla.id;

    isa-ok    $bla.one-ble,                 Ble;
    is        $bla.one-ble.value,           "test42";
};

subtest "Create on transaction", {
	throws-like {
		Bla.^create: :value<trans1>, :bles[{ :42value }]
	}, X::TypeCheck::Assignment, message => rx/value/;
	is Bla.^all.grep(*.value eq "trans1").elems, 0
};

done-testing;
