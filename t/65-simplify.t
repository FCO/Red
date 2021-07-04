use Test;
use Red;
use Red::Utils;
use Red::AST::Value;

model Bla {
    has Int $.id is serial;
    has Int $.a  is column;
    has Int $.b  is column;
    has Int $.c  is column;
}

my $*RED-DB = database "SQLite";

my \t = ast-value True;
my \f = ast-value False;

my $a = ast-value "X";
my $b = ast-value "Y";

ok compare($a.simplify, $a), "X => X";

test-simplify ($a AND $b AND $a),      ($a AND $b), "X && Y && X => X && Y";
test-simplify ($a AND $b AND $a.not),  f,           "X && Y && !X => False";
#quietly say .size, "  =>  ", $*RED-DB.translate($_).key for ($a AND $b AND $a.not).all-versions;

test-simplify ($a OR $b OR $a),        ($a OR $b),  "X || Y || X => X || Y";
test-simplify ($a OR $b OR $a.not),    t,           "X || Y || !X => X || Y";
#quietly say .size, "  =>  ", $*RED-DB.translate($_).key for ($a OR $b OR $a.not).all-versions;

test-simplify (($a AND $b).not OR $a), t,           "!(X && Y) || X => !X || !Y || X => True";

# examples
my \A = ast-value "A";
my \B = ast-value "B";
my \C = ast-value "C";

test-simplify (B OR (B AND C).not), t, "C || !(B && C) => True";

#| Take ages and gives the wrong answer
#test-simplify ((A AND B).not AND (A.not OR B) AND (B.not OR B)), A.not, "!(A && B) && (!A || B) && (!B || B) => !A";


done-testing;

sub test-simplify(Red::AST $a, Red::AST $b, $descr) {
    quietly diag "{ $*RED-DB.translate($a).key } => { $*RED-DB.translate($a.simplify).key }";
    ok compare($a.simplify, $b), $descr
}
