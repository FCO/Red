use Red::AST::Operator;

class Red::AST::Not { ... }

#| Base role for unary operators
role Red::AST::Unary does Red::AST::Operator {
    has Bool $.bind = False;
    method value { ... }

    method find-column-name {
        $.value.?find-column-name // Empty
    }

    method find-value {
        $.value.?find-value // Empty
    }

    method args { $.value }

    method gist {
        "{ $.op ~ " " if $.op.defined && $.op }{ $.value.?gist // "" }"
    }

    method new($value, Bool :$bind) {
        self.bless: :$value, :$bind
    }
}

#| Represents a cast operation
class Red::AST::Cast does Red::AST::Unary {
    has Str     $.type;
    has         $.value;

    multi translate(Int) { "num" }
    multi translate(Mu ) { ""    }

    method gist { "($!value.gist())::$!type" }

    method returns { $!type }

    method op { "::{$!type}" };

    method should-set {
        $!value.should-set
    }

    method new($value, $type, Bool :$bind) {
        return $value if $value.returns.&translate eq $type;
        self.bless: :$value, :$type, :$bind
    }

    method not { Red::AST::Not.new: self }
}

class Red::AST::So { ... }

#| Represents a not operation
class Red::AST::Not does Red::AST::Unary {
    has Str     $.type;
    has         $.value;
    has Bool    $.returns;
    method op { "not" };

    method should-set(|) { }

    method should-validate {}

    method not { Red::AST::So.new: $!value }
}

#| Represents a so operation
class Red::AST::So does Red::AST::Unary {
    has Str     $.type;
    has         $.value;
    has Bool    $.returns;
    method op { "" };

    method should-set(|) { }

    method should-validate {}

    method not { Red::AST::Not.new: $!value }
}
