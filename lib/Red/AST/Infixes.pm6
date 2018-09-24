use Red::AST::Infix;
class Red::AST::Eq does Red::AST::Infix {
    has $.op = "=";

    method should-set($class) {
        return if $.left.?class === $class and $.right.?class === $class;
    }

    method should-validate {}
}

class Red::AST::Ne does Red::AST::Infix {
    has $.op = "!=";

    method should-set { }

    method should-validate {}
}

class Red::AST::Lt does Red::AST::Infix {
    has $.op = "<";
    method should-set($class) { }
    method should-validate {}
}

class Red::AST::Gt does Red::AST::Infix {
    has $.op = ">";
    method should-set($class) { }
    method should-validate {}
}

class Red::AST::Le does Red::AST::Infix {
    has $.op = "<=";
    method should-set($class) { }
    method should-validate {}
}

class Red::AST::Ge does Red::AST::Infix {
    has $.op = ">=";
    method should-set($class) { }
    method should-validate {}
}

class Red::AST::AND does Red::AST::Infix {
    has $.op = "AND";

    method should-set($class) {
    }

    method should-validate {}
}

class Red::AST::OR does Red::AST::Infix {
    has $.op = "OR";

    method should-set($class) {
    }

    method should-validate {}
}

