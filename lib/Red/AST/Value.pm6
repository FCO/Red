use Red::AST;
class Red::AST::Value does Red::AST is Any {
    has Mu:U $.type;
    has      $.value is required;

    method TWEAK {
        $!type = $!value.WHAT
    }
    method args { $!value }
}

sub ast-value($value) is export {
    Red::AST::Value.new: :$value
}

