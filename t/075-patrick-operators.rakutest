#!/usr/bin/env raku

use lib "t/lib";

use Test;

use CITestSetManager;
use DB;
use Red:api<2>;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

my $*RED-FALLBACK = False;

schema(DB::CITestSet).drop.create;

my CITestSetManager $tsm .= new;

throws-like {
  $tsm.add-test-set();
}, X::Red::NoOperatorsDefined, message => /grep/;

throws-like {
  $tsm.add-test-set2();
}, X::Red::NoOperatorsDefined, message => /map/;

throws-like {
  $tsm.add-test-set3();
}, X::Red::NoOperatorsDefined, message => /first/;

done-testing
