use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;

#| An ordering expression with a direction independent of its selected value.
unit class Red::AST::Ordering does Red::AST;

has Red::AST $.value is required;
has Bool $.descending = False;

method returns { $!value.returns }
method args { $!value }
method find-column-name { $!value.find-column-name }
method reversed { self.clone(:descending(!$!descending)) }

method from-expression(Red::AST:D $expression) {
    return $expression if $expression ~~ Red::AST::Ordering;
    if $expression ~~ Red::AST::Mul && $expression.left ~~ Red::AST::Value
        && $expression.left.value ~~ Numeric && $expression.left.value == -1 {
        return self.new(:value($expression.right), :descending);
    }
    self.new(:value($expression))
}
