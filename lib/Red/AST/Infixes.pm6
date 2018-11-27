use Red::AST::Infix;
use Red::AST::Value;
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
class Red::AST::Mod     { ... }

class Red::AST::Eq does Red::AST::Infix {
    has $.op = "=";
    has Bool $.returns;

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

    method not {
        Red::AST::Ne.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::Ne does Red::AST::Infix {
    has $.op = "!=";
    has Bool $.returns;

    method should-set(--> Hash()) { }

    method should-validate {}

    method not {
        Red::AST::Eq.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::Lt does Red::AST::Infix {
    has $.op = "<";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Ge.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::Gt does Red::AST::Infix {
    has $.op = ">";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Le.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::Le does Red::AST::Infix {
    has $.op = "<=";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Gt.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::Ge does Red::AST::Infix {
    has $.op = ">=";
    has Bool $.returns;
    method should-set(--> Hash()) { }
    method should-validate {}

    method not {
        Red::AST::Lt.new: $.left, $.right, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::AND does Red::AST::Infix {
    has $.op = "AND";
    has Bool $.returns;

    multi method new(Red::AST $left is copy, Red::AST $right is copy) {
        my $args = $left | $right;
        if $args.isa(Red::AST::Value) and $args.value === False {
            return ast-value False
        }

        if $left ~~ Red::AST::Value and $left.value === True {
            return $right
        }

        if $right ~~ Red::AST::Value and $right.value === True {
            return $left
        }

        my $lcols = set $left.find-column-name;
        my $rcols = set $right.find-column-name;

        $left  .= value if $left ~~ Red::AST::So;
        $right .= value if $right ~~ Red::AST::So;

        my %cols := $lcols ∩ $rcols;
        if %cols == 1 {
            if ($left ~~ Red::AST::Ge or $left ~~ Red::AST::Gt)
                and ($right ~~ Red::AST::Ge or $right ~~ Red::AST::Gt) {
                my $lv = $left.args.first(*.^can: "get-value").get-value;
                my $rv = $right.args.first(*.^can: "get-value").get-value;
                if $lv.defined and $rv.defined {
                    if $rv > $lv {
                        return $right
                    } elsif $rv < $lv {
                        return $left
                    }
                }
            }
            if ($left ~~ Red::AST::Le or $left ~~ Red::AST::Lt)
                and ($right ~~ Red::AST::Le or $right ~~ Red::AST::Lt) {
                my $lv = $left.args.first(*.^can: "get-value").get-value;
                my $rv = $right.args.first(*.^can: "get-value").get-value;
                if $lv.defined and $rv.defined {
                    if $rv < $lv {
                        return $right
                    } elsif $rv > $lv {
                        return $left
                    }
                }
            }
            if $left ~~ Red::AST::Ge|Red::AST::Gt and $right ~~ Red::AST::Le|Red::AST::Lt {
                my $lv = $left.args.first(*.^can: "get-value").get-value;
                my $rv = $right.args.first(*.^can: "get-value").get-value;
                return ast-value False if $lv.defined and $rv.defined and $lv > $rv
            }
            if $left ~~ Red::AST::Le|Red::AST::Lt and $right ~~ Red::AST::Ge|Red::AST::Gt {
                my $lv = $left.args.first(*.^can: "get-value").get-value;
                my $rv = $right.args.first(*.^can: "get-value").get-value;
                return ast-value False if $lv.defined and $rv.defined and $lv < $rv
            }
        }

        ::?CLASS.bless: :$left, :$right
    }

    method should-set(--> Hash()) {
    }

    method should-validate {}

    method not {
        Red::AST::AND.new: $.left.not, $.right.not, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::OR does Red::AST::Infix {
    has $.op = "OR";
    has Bool $.returns;

    method should-set(--> Hash()) {
    }

    method should-validate {}

    method not {
        Red::AST::OR.new: $.left.not, $.right.not, :bind-left($.bind-left), :bind-right($.bind-right)
    }
}

class Red::AST::Mul does Red::AST::Infix {
    has $.op = "*";
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
