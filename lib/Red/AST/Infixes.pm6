use Red::AST::Infix;
class Red::AST::Eq does Red::AST::Infix {
    has $.op = " = ";

    method should-set($class) {
        return if $.left.?class === $class and $.right.?class === $class;
    }

    method should-validate {}
}

class Red::AST::Ne does Red::AST::Infix {
    has $.op = " != ";

    method should-set { }

    method should-validate {}
}
