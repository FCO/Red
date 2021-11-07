use Test;
use Red <has-one>;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

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
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Bla, Ble).drop.create;

# TODO: Figure out why this test can't be the last one
subtest "Create on has-one", {
    my $ble = Ble.^create(:value<ble>);
    my $bla = $ble.bla.^create: :value<bla>;
    is $bla.bles.head.gist, $ble.gist;
    is $ble.bla.gist, $bla.gist;
}

subtest "belogs-to using types", {
    model Blo { ... }
    model Bli {
        has UInt $.id      is serial;
        has Str  $.value   is column;
        has Blo  @.blos    is relationship(*.bli-id, :model(Blo));
        has Blo  $.one-blo is relationship(*.bli-id, :model(Blo), :has-one);
    }

    model Blo {
        has UInt $.id     is serial;
        has Str  $.value  is column;
        has UInt $.bli-id is referencing(*.id, :model(Bli));
        has Bli  $.bli    is relationship(*.bli-id, :model(Bli));
    }

    schema(Bli, Blo).create;

    my $blo = Blo.^create(:value<blo>);
    my $bli = $blo.bli.^create: :value<bli>;
    is $bli.blos.head.gist, $blo.gist;
    is $blo.bli.gist, $bli.gist;
}

# TODO: make this work
#subtest "belogs-to using types not using it on attrs", {
#    model Blu { ... }
#    model Blb {
#        has UInt $.id      is serial;
#        has Str  $.value   is column;
#        has      @.blus    is relationship(*.blb-id, :model(Blu));
#        has      $.one-blu is relationship(*.blb-id, :model(Blu), :has-one);
#    }
#
#    model Blu {
#        has UInt $.id     is serial;
#        has Str  $.value  is column;
#        has UInt $.blb-id is referencing(*.id, :model(Blb));
#        has      $.blb    is relationship(*.blb-id, :model(Blb));
#    }
#
#    schema(Blb, Blu).create;
#
#    my $blu = Blu.^create(:value<blu>);
#    my $blb = $blu.blb.^create: :value<blb>;
#    is $blb.blus.head.gist, $blu.gist;
#    is $blu.blb.gist, $blb.gist;
#}

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

subtest "Simple create and creating by array", {
    my $bla = Bla.^create: :value<test1>, :bles[{:value<test3>}, {:value<test4>}];

    isa-ok    $bla,                         Bla;
    is-deeply $bla,                         Bla.^load: $bla.id;

    does-ok   $bla.bles,                    Red::ResultSeq;
    isa-ok    $bla.bles,                    Ble::ResultSeq;
    is        $bla.bles.map(*.value),       <test3 test4>;
};

done-testing;
