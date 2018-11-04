use Red::AST::Infix;
class Red::AST::Eq does Red::AST::Infix {
    has $.op = "=";
    has Bool $.returns;

    method should-set(--> Hash()) {
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
    has Bool $.returns;

    method should-set(--> Hash()) { }

    method should-validate {}
}

class Red::AST::Lt does Red::AST::Infix {
    has $.op = "<";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::Gt does Red::AST::Infix {
    has $.op = ">";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::Le does Red::AST::Infix {
    has $.op = "<=";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::Ge does Red::AST::Infix {
    has $.op = ">=";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}
}

class Red::AST::AND does Red::AST::Infix {
    has $.op = "AND";
    has Bool $.returns;

    method should-set(--> Hash()) {
    }

    method should-validate {}
}

class Red::AST::OR does Red::AST::Infix {
    has $.op = "OR";
    has Bool $.returns;

    method should-set(--> Hash()) {
    }

    method should-validate {}
}

class Red::AST::Mul does Red::AST::Infix {
    has $.op = "*";
    has Num $.returns;

    method should-set(--> Hash()) {
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

class Red::AST::Div does Red::AST::Infix {
    has $.op = "/";
    has Num $.returns;

    method should-set(--> Hash()) {
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

class Red::AST::Mod does Red::AST::Infix {
    has $.op = "%";
    has Int $.returns;

    method should-set(--> Hash()) {
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
