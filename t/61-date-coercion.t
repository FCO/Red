#!/usr/bin/env raku

use Test;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;
use Red;

my DateTime $now .= now;

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model Foo {
	has Int  $.id is serial;
	has DateTime $.foo-date is column = $now;
}

Foo.^create-table;

Foo.^create;

my Str $today = $now.Date.Str;
ok Foo.^all.grep(*.foo-date.yyyy-mm-dd eq $today).elems, "explicit .yyyy-mm-dd";
ok Foo.^all.grep(*.foo-date eq $now.Date).elems, "eq with Date RHS";
ok Foo.^all.grep(*.foo-date == $now.Date).elems, "== with Date RHS";

done-testing;
