#!/usr/bin/env raku

use Red;
use Test;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model A {
    has Str $.id is id;
}

model B {
    has Int $.id is serial;
    has Str $.a-id is column({ name => 'a', model-name => 'A', column-name => 'id' });
    has     $.a    is relationship({ .a-id }, model => 'A');
    has Int $.c-id is referencing(model => 'C', column => 'id' );
    has     $.c is relationship({ .c-id }, model => 'C');
}

model C {
    has Int $.id is serial;
    has DateTime $.d is column = DateTime.now;
    has     @.bs is relationship({ .c-id }, model => 'B' );
}

schema(A, B, C).drop.create;

A.^create( id => 'FOO');

my $c = C.^create;

my $b;

lives-ok { $b = B.^new-from-data: { a => 'FOO', c_id => $c.id } }, "new-from-data with column names";
is $b.a-id, 'FOO', "got the FK in the attribute with the conflicting column name";
is $b.c-id, $c.id, "got the other FK right too";

done-testing;
# vim: ft=raku
