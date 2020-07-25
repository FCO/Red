use Test;
use Red;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model M is table<mmm> {
    has Int $.a is column
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(M).drop;
M.^create-table;

M.^create: :a($_) for ^30;

my $union1 = M.^all.grep(*.a < 10) (|) M.^all.grep(*.a > 20);
isa-ok $union1, M::ResultSeq;
isa-ok $union1.ast, Red::AST::Union;
is-deeply $union1.map(*.a).Seq.sort, (|^10, |(20 ^..^ 30));

my $union2 = M.^all.grep(*.a < 10) ∪ M.^all.grep(*.a > 20);
isa-ok $union2, M::ResultSeq;
isa-ok $union2.ast, Red::AST::Union;
is-deeply $union2.map(*.a).Seq.sort, (|^10, |(20 ^..^ 30));

my $intersect1 = M.^all.grep(*.a > 10) (&) M.^all.grep(*.a < 20);
isa-ok $intersect1, M::ResultSeq;
isa-ok $intersect1.ast, Red::AST::Intersect;
is-deeply $intersect1.map(*.a).Seq.sort, eager 10 ^..^ 20;

my $intersect2 = M.^all.grep(*.a > 10) ∩ M.^all.grep(*.a < 20);
isa-ok $intersect2, M::ResultSeq;
isa-ok $intersect2.ast, Red::AST::Intersect;
is-deeply $intersect2.map(*.a).Seq.sort, eager 10 ^..^ 20;

plan :skip-all("Pg do not accept minus") with %*ENV<RED_DATABASE>;
my $minus1 = M.^all (-) M.^all.grep(*.a >= 20);
isa-ok $minus1, M::ResultSeq;
isa-ok $minus1.ast, Red::AST::Minus;
is-deeply $minus1.map(*.a).Seq.sort, eager ^20;

my $minus2 = M.^all ⊖ M.^all.grep(*.a >= 20);
isa-ok $minus2, M::ResultSeq;
isa-ok $minus2.ast, Red::AST::Minus;
is-deeply $minus2.map(*.a).Seq.sort, eager ^20;

done-testing
