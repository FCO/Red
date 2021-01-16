use Test;
use Red <no-optimization>;

for <AND OR Case> -> $infix {
	ok so ::("Red::AST::$infix").^roles.map(*.^name).none eq "Red::AST::Optimizer::$infix";
}

done-testing
