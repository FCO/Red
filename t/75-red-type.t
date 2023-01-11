#!/usr/bin/env raku

use Test;
use Red;
use Red::Type;

my $*RED-FALLBACK       = False;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

class Point {
   has $.x;
   has $.y;
}

class DBPoint does Red::Type {
   method inflator {
     -> Str $_ --> Point { do given .split: "," -> ($x, $y) { Point.new: :$x, :$y } }
   }
   method deflator {
     -> Point $_ --> Str { "{.x},{.y}" }
   }
   method red-type-column-type    { "string" }
   method red-type-accepts(Point) { True }
}

model Place {
   has UInt    $.id    is serial;
   has DBPoint $.point is column;
}

schema(Place).drop.create;

Place.^create: :point(Point.new: :0x, :10y);
my $p = Place.^all.head;

isa-ok $p, Place;
isa-ok $p.point, Point;
is $p.point.x, 0;
is $p.point.y, 10;

done-testing
