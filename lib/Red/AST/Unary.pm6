use Red::AST::Operator;
class Red::AST::Cast does Red::AST::Operator {
    has Str $.type;
    has     $.value;
    method op { "::{$!type}" };

    method should-set(|) { }

    method should-validate {}

    method new($value, $type) {
        ::?CLASS.bless: :$value, :$type
    }
}
