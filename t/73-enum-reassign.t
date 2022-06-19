#!/usr/bin/env raku
use Test;
use Red;

# TODO: Is it breaking for Pg?
plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

enum E <E1>;

model M {
    has E $.e is column is rw;
}
my M $m1 .= new: e => E1;

my M $m2;
lives-ok {
    $m2 .= new: e => $m1.e;
    is $m2.e, E1;
}

done-testing
