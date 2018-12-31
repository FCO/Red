use v6;
use Test;

use Red;


my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

subtest {
    model TestDuration {
        has Int         $.id is serial;
        has Duration    $.duration is column;
    }

    lives-ok { TestDuration.^create-table }, "create table with Duration column";
    my TestDuration $row;
    lives-ok { $row = TestDuration.^create(duration => Duration.new(10)) }, "create row with Duration";
    todo "Not yet coercing values from DB";
    isa-ok $row.duration, Duration;
}, "test Duration";


done-testing;
# vim: ft=perl6


