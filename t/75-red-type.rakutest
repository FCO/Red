#!/usr/bin/env raku

use Test;
use Red;
use Red::Type;
use Red::AST::Value;
use Red::AST::Unary;

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
     -> $_ --> Point { Point.new: :x(.<x>), :y(.<y>) }
   }
   method deflator {
     -> Point $_ { %( :x(.x), :y(.y) ) }
   }
   method red-type-column-type    { "jsonb" }
   method red-type-accepts(Point) { True }
   method red-type-db-methods {
    role :: {
      method x { Red::AST::Cast.new: Red::AST::JsonItem.new(self, ast-value "x"), "integer" }
      method y { Red::AST::Cast.new: Red::AST::JsonItem.new(self, ast-value "y"), "integer" }
    }
   }
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

.say for Place.^all.grep: *.point.x >= 0;

done-testing
