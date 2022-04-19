#!/usr/bin/env raku

use Test;

use Red;


my $*RED-FALLBACK       = False;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model Bar::Foo is table('foo') {
	has Str $.a is column;
	has Str $.b is column;
	has Str $.c is column;
	has Date $.foo-date is column = Date.today;
}

schema(Bar::Foo).drop.create;

my Date $today = Date.today;
my Date $yesterday = Date.today.earlier(days => 1);

lives-ok {
    Bar::Foo.^rs.grep(*.foo-date eq $yesterday ).join-model( Bar::Foo, -> $a, $b {  $a.a == $b.a   && $a.b == $b.b && $a.c == $b.c  && $b.foo-date eq $today }, name => "foo_2" ).elems
}, "join-model with nested package name";

done-testing;
