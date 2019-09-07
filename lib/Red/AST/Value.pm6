use Red::AST;
use Red::Column;
class Red::AST::Value does Red::AST is Any {
    has             $.value is required;
    has Red::Column $.column;
    has Mu:U        $.type = $!value.WHAT; # $!column.DEFINITE ?? $!column.attr.type !! $!value.WHAT

    method gist { $!value.gist }
    method returns { $!type }

    method args { $!value }

    method find-value { $!value }

    method find-column-name {}

    method get-value() {
        do if $!column.DEFINITE {
            $!column.deflate.($!value)
        } else {
            $!value
        }
    }
}

multi ast-value(Red::AST $value) is export {
    $value
}

multi ast-value($value, :$type) is export {
    Red::AST::Value.new: :$value, |(:$type with $type)
}

