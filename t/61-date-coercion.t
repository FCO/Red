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

ok Foo.^all.grep(*.foo-date.date eq '2021-06-30').elems, "explicit .date";
ok Foo.^all.grep(*.foo-date eq Date.today).elems, "eq with Date RHS";
ok Foo.^all.grep(*.foo-date == Date.today).elems, "== with Date RHS";

done-testing;
