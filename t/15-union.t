use Test;
use Red;

model M is table<mmm> {
    has Int $.a is column
}

my $*RED-DB = database "SQLite";
my $*RED-DEBUG = True if %*ENV<RED_DEBUG>;

M.^create-table;

M.^create: :a($_) for ( ^29 + 1 );

my $union1 = M.^all.grep(*.a < 10) (|) M.^all.grep(*.a > 20);
isa-ok $union1, M::ResultSeq;
isa-ok $union1.ast, Red::AST::Union;
is-deeply $union1.map(*.a).Seq, (|(^9 + 1), |(20 ^..^ 30));

my $union2 = M.^all.grep(*.a < 10) ∪ M.^all.grep(*.a > 20);
isa-ok $union2, M::ResultSeq;
isa-ok $union2.ast, Red::AST::Union;
is-deeply $union2.map(*.a).Seq, (|(^9 + 1), |(20 ^..^ 30));

my $intersect1 = M.^all.grep(*.a > 10) (&) M.^all.grep(*.a < 20);
isa-ok $intersect1, M::ResultSeq;
isa-ok $intersect1.ast, Red::AST::Intersect;
is-deeply $intersect1.map(*.a).Seq, eager 10 ^..^ 20;

my $intersect2 = M.^all.grep(*.a > 10) ∩ M.^all.grep(*.a < 20);
isa-ok $intersect2, M::ResultSeq;
isa-ok $intersect2.ast, Red::AST::Intersect;
is-deeply $intersect2.map(*.a).Seq, eager 10 ^..^ 20;

my $minus1 = M.^all (-) M.^all.grep(*.a >= 20);
isa-ok $minus1, M::ResultSeq;
isa-ok $minus1.ast, Red::AST::Minus;
is-deeply $minus1.Seq.map(*.a), eager (^19 + 1);

my $minus2 = M.^all ⊖ M.^all.grep(*.a >= 20);
isa-ok $minus2, M::ResultSeq;
isa-ok $minus2.ast, Red::AST::Minus;
is-deeply $minus2.Seq.map(*.a), eager (^19 + 1);

done-testing
