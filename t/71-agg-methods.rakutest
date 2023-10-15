#!/usr/bin/env raku

use Red;
use Test;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model TempSensor {
  has UInt     $.location-id is column{ :references(*.id), :model-name<Location>, :id }
  has DateTime $.created-at  is id .= now;
  has Int      $.temperature is column;
}

model Location {
  has UInt       $.id    is serial;
  has Str        $.name  is unique;
  has TempSensor @.temps is relationship( *.location-id );
}

schema(TempSensor, Location).drop.create;

Location.^create(
  :name(" location" ~ ++$),
  :temps(^10 .map(-> $temperature { %( :$temperature ) }))
) xx 3;

is Location.^all.map({ .name, .temps.min(*.temperature), .temps.max(*.temperature) }).Seq.flat, " location1 0 9  location2 0 9  location3 0 9";

lives-ok {
  my @all := Location.^all.map({ .temps.max(*.temperature) });
  is $_, "9 9 9" for await start { @all.Seq.flat } xx 30
}

done-testing
