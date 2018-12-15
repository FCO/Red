use Test;
use Red;
use Red::AST::Value;

model C {
    has Int $.a is column;
    has Int $.b is column;
    has Str $.c is column;
}

my \f = ast-value False;
my \t = ast-value True;

is-deeply (f AND f), ast-value False;
is-deeply (f AND C.a), ast-value False;
is-deeply (C.a AND f), ast-value False;
is-deeply (t AND C.a), C.a;
is-deeply (C.a AND t), C.a;
is-deeply ((C.a) AND not (C.a)), ast-value True;

is-deeply ((C.a > 1)  AND (C.a > 10) ), (C.a > 10);
is-deeply ((C.a >= 1) AND (C.a > 10) ), (C.a > 10);
is-deeply ((C.a > 1)  AND (C.a >= 10)), (C.a >= 10);
is-deeply ((C.a >= 1) AND (C.a >= 10)), (C.a >= 10);

is-deeply ((C.a > 10)  AND (C.a > 1) ), (C.a > 10);
is-deeply ((C.a > 10)  AND (C.a >= 1)), (C.a > 10);
is-deeply ((C.a >= 10) AND (C.a > 1) ), (C.a >= 10);
is-deeply ((C.a >= 10) AND (C.a >= 1)), (C.a >= 10);

is-deeply ((C.a < 1)  AND (C.a < 10) ), (C.a < 1);
is-deeply ((C.a <= 1) AND (C.a < 10) ), (C.a <= 1);
is-deeply ((C.a < 1)  AND (C.a <= 10)), (C.a < 1);
is-deeply ((C.a <= 1) AND (C.a <= 10)), (C.a <= 1);

is-deeply ((C.a < 10)  AND (C.a < 1) ), (C.a < 1);
is-deeply ((C.a < 10)  AND (C.a <= 1)), (C.a <= 1);
is-deeply ((C.a <= 10) AND (C.a < 1) ), (C.a < 1);
is-deeply ((C.a <= 10) AND (C.a <= 1)), (C.a <= 1);

is-deeply ((C.a < 1)  AND (C.a > 10) ), ast-value False;
is-deeply ((C.a <= 1) AND (C.a > 10) ), ast-value False;
is-deeply ((C.a < 1)  AND (C.a >= 10)), ast-value False;
is-deeply ((C.a <= 1) AND (C.a >= 10)), ast-value False;

is-deeply ((C.a > 10)  AND (C.a < 1) ), ast-value False;
is-deeply ((C.a > 10)  AND (C.a <= 1)), ast-value False;
is-deeply ((C.a >= 10) AND (C.a < 1) ), ast-value False;
is-deeply ((C.a >= 10) AND (C.a <= 1)), ast-value False;


done-testing
