use Test;
use Red::AST::Value;
use Red;

model C {
    has Int $.a is column;
    has Int $.b is column;
    has Str $.c is column;
}

my \f = ast-value False;
my \t = ast-value True;

is-deeply (f AND f), f;
is-deeply (f AND t), f;
is-deeply (t AND f), f;
is-deeply (t AND t), t;

is-deeply (f AND C.a), f;
is-deeply (C.a AND f), f;
is-deeply (t AND C.a), C.a;
is-deeply (C.a AND t), C.a;

is-deeply ((C.a) AND not (C.a)), t;

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

is-deeply ((C.a < 1)  AND (C.a > 10) ), f;
is-deeply ((C.a <= 1) AND (C.a > 10) ), f;
is-deeply ((C.a < 1)  AND (C.a >= 10)), f;
is-deeply ((C.a <= 1) AND (C.a >= 10)), f;

is-deeply ((C.a > 10)  AND (C.a < 1) ), f;
is-deeply ((C.a > 10)  AND (C.a <= 1)), f;
is-deeply ((C.a >= 10) AND (C.a < 1) ), f;
is-deeply ((C.a >= 10) AND (C.a <= 1)), f;





#is-deeply (f OR f), ast-value False;
is-deeply (f OR C.a), ast-value C.a;
is-deeply (C.a OR f), ast-value C.a;
is-deeply (t OR C.a), t;
is-deeply (C.a OR t), t;
is-deeply ((C.a) OR not (C.a)), t;

is-deeply ((C.a > 1)  OR (C.a > 10) ), (C.a > 10);
is-deeply ((C.a >= 1) OR (C.a > 10) ), (C.a > 10);
is-deeply ((C.a > 1)  OR (C.a >= 10)), (C.a >= 10);
is-deeply ((C.a >= 1) OR (C.a >= 10)), (C.a >= 10);

is-deeply ((C.a > 10)  OR (C.a > 1) ), (C.a > 10);
is-deeply ((C.a > 10)  OR (C.a >= 1)), (C.a > 10);
is-deeply ((C.a >= 10) OR (C.a > 1) ), (C.a >= 10);
is-deeply ((C.a >= 10) OR (C.a >= 1)), (C.a >= 10);

is-deeply ((C.a < 1)  OR (C.a < 10) ), (C.a < 1);
is-deeply ((C.a <= 1) OR (C.a < 10) ), (C.a <= 1);
is-deeply ((C.a < 1)  OR (C.a <= 10)), (C.a < 1);
is-deeply ((C.a <= 1) OR (C.a <= 10)), (C.a <= 1);

is-deeply ((C.a < 10)  OR (C.a < 1) ), (C.a < 1);
is-deeply ((C.a < 10)  OR (C.a <= 1)), (C.a <= 1);
is-deeply ((C.a <= 10) OR (C.a < 1) ), (C.a < 1);
is-deeply ((C.a <= 10) OR (C.a <= 1)), (C.a <= 1);

is-deeply ((C.a > 1)  OR (C.a < 10) ), t;
is-deeply ((C.a >= 1) OR (C.a < 10) ), t;
is-deeply ((C.a > 1)  OR (C.a <= 10)), t;
is-deeply ((C.a >= 1) OR (C.a <= 10)), t;

is-deeply ((C.a < 10)  OR (C.a > 1) ), t;
is-deeply ((C.a < 10)  OR (C.a >= 1)), t;
is-deeply ((C.a <= 10) OR (C.a > 1) ), t;
is-deeply ((C.a <= 10) OR (C.a >= 1)), t;

done-testing
