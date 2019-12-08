use Test;
use Red;

model Bla {
    has UInt $.id     is serial;
    has Str  $.value  is column;
    has      @.bles   is relationship(*.bla-id, :model<Ble>);
}

model Ble {
    has UInt $.id     is serial;
    has Str  $.value  is column;
    has UInt $.bla-id is referencing(*.id, :model<Bla>);
    has      $.bla    is relationship(*.bla-id, :model<Bla>);
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

Bla.^create-table;
Ble.^create-table;

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

done-testing;
