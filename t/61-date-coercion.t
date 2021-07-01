#!/usr/bin/env raku

use Test;

use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

model Foo {
	has Int  $.id is serial;
	has DateTime $.foo-date is column = DateTime.now;
}

Foo.^create-table;

Foo.^create;

my Str $today = Date.today.Str;
ok Foo.^all.grep(*.foo-date.yyyy-mm-dd eq $today).elems, "explicit .yyyy-mm-dd";
ok Foo.^all.grep(*.foo-date eq Date.today).elems, "eq with Date RHS";
ok Foo.^all.grep(*.foo-date == Date.today).elems, "== with Date RHS";

done-testing;
