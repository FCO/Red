use Red::AST;
use Red::Column;
class Red::AST::Value does Red::AST is Any {
    has Mu:U        $.type;
    has             $.value is required;
    has Red::Column $.column;

    method TWEAK {
        $!type = $!column.defined ?? $!column.attr.type !! $!value.WHAT
    }
    method args { $!value }

    method find-value { $!value }
}

sub ast-value($value) is export {
    Red::AST::Value.new: :$value
}

