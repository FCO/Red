use Red::Column;
use Red::AST::Infix;
class Red::AST::Eq does Red::AST::Infix {
    has $.op = "=";

    method should-set(--> Hash()) {
        say self;
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        for self.args {
            .return with .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}

class Red::AST::Ne does Red::AST::Infix {
    has $.op = "!=";

    method should-set(--> Hash()) { }

    method should-validate {}
}

class Red::AST::Lt does Red::AST::Infix {
    has $.op = "<";
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::Gt does Red::AST::Infix {
    has $.op = ">";
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::Le does Red::AST::Infix {
    has $.op = "<=";
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::Ge does Red::AST::Infix {
    has $.op = ">=";
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::AND does Red::AST::Infix {
    has $.op = "AND";

    method should-set(--> Hash()) {
    }

    method should-validate {}
}

class Red::AST::OR does Red::AST::Infix {
    has $.op = "OR";

    method should-set(--> Hash()) {
    }

    method should-validate {}
}

