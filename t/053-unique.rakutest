use Test;
use Red;

model AAA {
    has Int $.id is serial;
    has Str $.a1 is unique;
    has Str $.a2 is unique;
    has Str $.a3 is unique;
}

is AAA.^unique-constraints.elems, 3;

model BBB {
    has Int $.id is serial;
    has Str $.a1 is unique<a b>;
    has Str $.a2 is unique<a b c d>;
    has Str $.a3 is unique<a>;
}

is BBB.^unique-constraints.elems, 4;
is-deeply BBB.^unique-constraints.map(*.list.Str).sort, ('$!a1 $!a2', '$!a1 $!a2 $!a3', '$!a2', '$!a2');

done-testing
