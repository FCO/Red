#!/usr/bin/env raku
use Test;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-FALLBACK       = False;
my $*RED-DB;

my $test-set;

lives-ok {
    use Red:api<2>;
    $*RED-DB = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

    $test-set = model CITestSet is rw is table<citest_set> {
        has UInt $.id    is serial;
        has Str $.status is column;
    }

    schema($test-set).create;
}

my $ts = $test-set.^create: :status<NEW>;
todo "Find a way to die if ⊂ is not overwritten", 1;
dies-ok { $ts.^all.grep: *.status ⊂ <a b c> };
dies-ok { $ts.^all.grep: *.status > 5       };

done-testing;
