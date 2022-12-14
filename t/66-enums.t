#!/usr/bin/env raku

use Test;
use Red:api<2> <refreshable>;
#
# TODO: Is it breaking for Pg?
plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

my $*RED-FALLBACK       = False;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

enum E <a b c>;
enum V ( d => "a", e => "b", f => "c" );

model M is rw {
    has UInt $.id is serial;
    has E    $.my-e is column;
}

model N is rw {
    has UInt $.id is serial;
    has V    $.my-v is column;
}
schema(M, N).drop.create;

M.^create(my-e => a);
N.^create(my-v => d);

is M.^all.grep(*.my-e == a).elems, 1, "Enum column, integer enum RHS ==";
is M.^all.grep(*.my-e ⊂ [a]).elems, 1, "Enum column, single item integer enum list IN";
is M.^all.grep(*.my-e ⊂ (a, b)).elems, 1, "Enum column, list of integer enums RHS IN";

is N.^all.grep(*.my-v eq d).elems, 1, "Enum column, string enum RHS eq";
is N.^all.grep(*.my-v ⊂ [d]).elems, 1, "Enum column, single item string enum list IN";
is N.^all.grep(*.my-v ⊂ (d, e)).elems, 1, "Enum column, list of string enums RHS IN";

done-testing();
