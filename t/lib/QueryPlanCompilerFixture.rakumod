unit module QueryPlanCompilerFixture;
use Red;
use Red::Compiler::RakuAST;

CHECK red-compile if (%*ENV<RAKUDO_RAKUAST> // '0') eq '1';

model PrecompiledPlanRow {
    has Int $.number is column;
}

sub cached-query(Int $minimum) is export {
    PrecompiledPlanRow.^all.grep({ .number > $minimum })
}

# A different value would reveal recompilation in the second importing process.
my constant compilation-token = BEGIN now.Str ~ ':' ~ 1000000000.rand.Int;
sub precomp-token() is export { compilation-token }
