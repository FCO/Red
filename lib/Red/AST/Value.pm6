use Red::AST;
use Red::Column;
class Red::AST::Value does Red::AST is Any {
    has             $.value is required;
    has Mu:U        $.type = $!value.WHAT;
    has Red::Column $.column;

    method TWEAK {
        #$!type = $!column.defined ?? $!column.attr.type !! $!value.WHAT
    }
    method args { $!value }

    method find-value { $!value }

    method get-value() {
        do with $!column {
            .deflate.($!value)
        } else {
            $!value
        }
    }
}

sub ast-value($value) is export {
    Red::AST::Value.new: :$value
}

