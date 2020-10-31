use Test;
use Red;

model AAA {
    has Int $.id is serial;
    has Str $.a1 is unique;
    has Str $.a2 is unique;
    has Str $.a3 is unique;
}

is AAA.^unique-constraints.elems, 3;

done-testing
