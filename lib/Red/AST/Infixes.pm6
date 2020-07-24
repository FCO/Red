use Red::AST::Infix;
use Red::AST::Value;
class Red::AST::Sum     { ... }
class Red::AST::Eq      { ... }
class Red::AST::Ne      { ... }
class Red::AST::Lt      { ... }
class Red::AST::Gt      { ... }
class Red::AST::Le      { ... }
class Red::AST::Ge      { ... }
class Red::AST::AND     { ... }
class Red::AST::OR      { ... }
class Red::AST::Mul     { ... }
class Red::AST::Div     { ... }
class Red::AST::IDiv    { ... }
class Red::AST::Mod     { ... }
class Red::AST::Concat  { ... }
class Red::AST::Like    { ... }
class Red::AST::In      { ... }

#| Represents a sum operation
class Red::AST::Sum does Red::AST::Infix {
    has $.op = "+";
    has $.returns = (self.left | self.right).returns ~~ Num ?? Num !! Int;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}

#| Represents a subtraction operation
class Red::AST::Sub does Red::AST::Infix {
    has $.op = "-";
    has $.returns = (self.left | self.right).returns ~~ Num ?? Num !! Int;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}

#| Represents a equality operation
class Red::AST::Eq does Red::AST::Infix {
    has $.op = "=";
    has Bool $.returns;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take if .defined for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }

    method not {
        Red::AST::Ne.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a not equality operation
class Red::AST::Ne does Red::AST::Infix {
    has $.op = "!=";
    has Bool $.returns;

    method should-set(--> Hash()) { }

    method should-validate {}

    method not {
        Red::AST::Eq.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a less than operation
class Red::AST::Lt does Red::AST::Infix {
    has $.op = "<";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Ge.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a greater than operation
class Red::AST::Gt does Red::AST::Infix {
    has $.op = ">";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Le.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a less than equal operation
class Red::AST::Le does Red::AST::Infix {
    has $.op = "<=";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Gt.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a greater then equal operation
class Red::AST::Ge does Red::AST::Infix {
    has $.op = ">=";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Lt.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a AND operation
class Red::AST::AND does Red::AST::Infix {
    #also does Red::AST::Optimizer::And;

    has $.op = "AND";
    has Bool $.returns;

    multi method new(Red::AST $left is copy, Red::AST $right is copy) {
        my \ret = self.optimize: $left, $right;
        return ret if ret.DEFINITE && ret !~~ Empty;

        $left  .= value if $left  ~~ Red::AST::So;
        $right .= value if $right ~~ Red::AST::So;

        return $left if $left eqv $right;
        return ast-value(False) if $left eqv $right.not;

        self.WHAT.bless: :$left, :$right
    }

    method should-set(--> Hash()) {
        [$.left, $.right].flatmap({ .should-set })
    }

    method should-validate {}

    method not {
        Red::AST::OR.new: $.left.not, $.right.not, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a OR operation
class Red::AST::OR does Red::AST::Infix {
    #also does Red::AST::Optimizer::OR;
    has $.op = "OR";
    has Bool $.returns;

    multi method new(Red::AST $left is copy, Red::AST $right is copy) {
        my \ret = self.optimize: $left, $right;
        return ret if ret.DEFINITE && ret !~~ Empty;

        $left  .= value if $left  ~~ Red::AST::So;
        $right .= value if $right ~~ Red::AST::So;

        return $left if $left eqv $right;
        return ast-value(True) if $left eqv $right.not;

        self.WHAT.bless: :$left, :$right
    }

    method should-set(--> Hash()) {}

    method should-validate {}

    method not {
        Red::AST::AND.new: $.left.not, $.right.not, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

#| Represents a multiplication operation
class Red::AST::Mul does Red::AST::Infix {
    has $.op = "*";
    has $.returns = (self.left | self.right).returns ~~ Num ?? Num !! Int;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}

#| Represents a division operation
class Red::AST::Div does Red::AST::Infix {
    has $.op = "/";
    has Num $.returns;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}


#| Represents a division operation
class Red::AST::IDiv does Red::AST::Infix {
    has $.op = "/";
    has Int $.returns;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}

#| Represents a module operation
class Red::AST::Mod does Red::AST::Infix {
    has $.op = "%";
    has Int $.returns;

    method should-set(--> Hash()) {
        self.find-column-name => self.find-value
    }

    method should-validate {}

    method find-column-name {
        gather for self.args {
            .take for .?find-column-name
        }
    }

    method find-value {
        for self.args {
            .return with .?find-value
        }
    }
}

#| Represents a concatenation operation
class Red::AST::Concat does Red::AST::Infix {
    has $.op = "||";
    has Str $.returns;

    method should-set(--> Hash()) {}

    method should-validate {}

    multi method new(Red::AST $left, Red::AST::Value $ where .value eq "",  *%) { $left }
    multi method new(Red::AST::Value $ where .value eq "", Red::AST $right, *%) { $right }
}

#| Represents a like operation
class Red::AST::Like does Red::AST::Infix {
    has $.op = "like";
    has Str $.returns;

    method should-set(--> Hash()) {}

    method should-validate {}

    multi method new(Red::AST $left, Red::AST::Value $ where .value eq "",  *%) { $left }
}

#| Represents a not in operation
class Red::AST::NotIn does Red::AST::Infix {
    has $.op = "NOT IN";
    has Str $.returns;

    method should-set(--> Hash()) {}

    method should-validate {}

    method not {
        Red::AST::In.new: $!left, $!right;
    }
}

#| Represents a in operation
class Red::AST::In does Red::AST::Infix {
    has $.op = "IN";
    has Str $.returns;

    method should-set(--> Hash()) {}

    method should-validate {}

    method not {
        Red::AST::NotIn.new: $!left, $!right;
    }
}
