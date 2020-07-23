use Test;
use Red;

model Bla {
    has UInt $!id is serial;
    has Str $.bla is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

Bla.^create-table;
Bla.^create: :bla<test1>;
Bla.^create: :bla<test1>;
Bla.^create: :bla<test2>;

my %a := Bla.^all.classify({ .bla });
is %a.elems, 2;
is %a<test1>.elems, 2;
is %a<test2>.elems, 1;
my %b := Bla.^all.map(*.bla).classify({ .self });
is %b.elems, 2;
is %b<test1>.elems, 2;
is %b<test2>.elems, 1;
my %c := Bla.^all.map(*.bla).classify(* eq "test1");
is %c.elems, 2;
is %c.keys.Seq.sort, (0, 1);
is %c{1}.elems, 2;
is %c{0}.elems, 1;
is-deeply Bla.^all.classify(*.bla).Bag, bag(<test1 test1 test2>);
is-deeply Bla.^all.classify(*.bla).Set, set(<test1 test2>);
is-deeply Bla.^all.map(*.bla).Bag, bag(<test1 test1 test2>);
is-deeply Bla.^all.map(*.bla).Set, set(<test1 test2>);

done-testing;
