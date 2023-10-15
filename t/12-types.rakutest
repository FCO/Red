use v6;
use Test;

use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

subtest {
    model TestDuration {
        has Int         $.id is serial;
        has Duration    $.duration is column;
    }

    schema(TestDuration).drop;
    lives-ok { TestDuration.^create-table }, "create table with Duration column";
    my TestDuration $row;
    lives-ok { $row = TestDuration.^create(duration => Duration.new(10)) }, "create row with Duration";
    isa-ok $row.duration, Duration;
}, "test Duration";

subtest {
    model UnknownType {
        has Str $.unknown is id;
    }

    schema(UnknownType).drop;

    UnknownType.^create-table;
    UnknownType.^create: :unknown<bla>;

    class Bla { has $.value; method Str { ~$!value } }

    lives-ok {
        is UnknownType.^load(:unknown(Bla.new: :value<bla>)).unknown, "bla"
    }
}

done-testing;
# vim: ft=perl6


