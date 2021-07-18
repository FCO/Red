#!/usr/bin/env raku

use Test;

use Red;


my $*RED-FALLBACK       = False;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

enum E <a b c>;

model M is rw {
    has UInt $.id is serial;
    has E    $.my-e is column;
}
schema(M).create;
M.^create(my-e => a);

is M.^all.grep(*.my-e == a)    .map(*.my-e).Seq, a;
is M.^all.grep(*.my-e === a)   .map(*.my-e).Seq, a;
is M.^all.grep(*.my-e ⊂ (a))   .map(*.my-e).Seq, a;
is M.^all.grep(*.my-e ⊂ (a, b)).map(*.my-e).Seq, a;

done-testing
