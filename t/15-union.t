use Test;
use Red;

model M is table<mmm> {
    has Int $.a is column
}

my $*RED-DB = database "SQLite";

M.^create-table;

M.^create: :a($_) for ^30;

my $union1 = M.^all.grep(*.a < 10) (|) M.^all.grep(*.a > 20);
isa-ok $union1, M::ResultSeq;
isa-ok $union1.ast, Red::AST::Union;
is-deeply $union1.Seq.map(*.a), (|^10, |(20 ^..^ 30));  # TODO: Fix map

my $union2 = M.^all.grep(*.a < 10) ∪ M.^all.grep(*.a > 20);
isa-ok $union2, M::ResultSeq;
isa-ok $union2.ast, Red::AST::Union;
is-deeply $union2.Seq.map(*.a), (|^10, |(20 ^..^ 30));  # TODO: Fix map

my $intersect1 = M.^all.grep(*.a > 10) (&) M.^all.grep(*.a < 20);
isa-ok $intersect1, M::ResultSeq;
isa-ok $intersect1.ast, Red::AST::Intersect;
is-deeply $intersect1.Seq.map(*.a), eager 10 ^..^ 20;   # TODO: Fix map

my $intersect2 = M.^all.grep(*.a > 10) ∩ M.^all.grep(*.a < 20);
isa-ok $intersect2, M::ResultSeq;
isa-ok $intersect2.ast, Red::AST::Intersect;
is-deeply $intersect2.Seq.map(*.a), eager 10 ^..^ 20;   # TODO: Fix map

# TODO: Fix it
#my $minus1 = M.^all (-) M.^all.grep(*.a > 20);
#isa-ok $minus1, M::ResultSeq;
#isa-ok $minus1.ast, Red::AST::Minus;
#is-deeply $minus1.Seq.map(*.a), eager ^20;

#my $minus2 = M.^all ⊖ M.^all.grep(*.a > 20);
#isa-ok $minus2, M::ResultSeq;
#isa-ok $minus2.ast, Red::AST::Minus;
#is-deeply $minus2.Seq.map(*.a), eager ^20;

done-testing
