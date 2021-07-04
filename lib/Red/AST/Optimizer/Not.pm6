use Red::AST;
use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::Utils;

unit role Red::AST::Optimizer::NOT;

=head2 Red::AST::Optimizer::AND

#| All possible versions
method all-versions {
    |do for $.value.all-versions {
        |(.not, do given $_ {
            when Red::AST::AND -> (Red::AST :$l, RED::AST $r){
                |do for [$l, $r], [$l, $r] -> ($left, $right) {
                    Red::AST::OR.new: $left.not, $right.not
                }
            }
        })
    }.unique
}
