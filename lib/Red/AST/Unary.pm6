use Red::AST::Operator;

class Red::AST::Not { ... }

role Red::AST::Unary does Red::AST::Operator {
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
}

class Red::AST::Cast does Red::AST::Unary {
    has Str     $.type;
    has         $.value;

    method gist { "($!value.gist())::$!type" }

    method returns { $!type }

    method op { "::{$!type}" };

    method should-set {
        $!value.should-set
    }

    method new($value, $type) {
        ::?CLASS.bless: :$value, :$type
    }


    method not { Red::AST::Not.new: self }
}

class Red::AST::So { ... }

class Red::AST::Not does Red::AST::Unary {
    has Str     $.type;
    has         $.value;
    has Bool    $.returns;
    method op { "not" };

    method should-set(|) { }

    method should-validate {}

    multi method new(Red::AST $value) {
        ::?CLASS.bless: :$value
    }

    method not { Red::AST::So.new: $!value }
}

class Red::AST::So does Red::AST::Unary {
    has Str     $.type;
    has         $.value;
    has Bool    $.returns;
    method op { "" };

    method should-set(|) { }

    method should-validate {}

    method new($value) {
        ::?CLASS.bless: :$value
    }

    method not { Red::AST::Not.new: $!value }
}
