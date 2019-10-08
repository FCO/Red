use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::Utils;

unit role Red::AST::Optimizer::AND;

=head2 Red::AST::Optimizer::AND

my subset AstFalse of Red::AST::Value where { .value === False };
my subset AstTrue  of Red::AST::Value where { .value === True  };

my subset GeGt of Red::AST::Infix where Red::AST::Ge|Red::AST::Gt;
my subset LeLt of Red::AST::Infix where Red::AST::Le|Red::AST::Lt;


multi method optimize(Red::AST $left, Red::AST $right where compare($left, .not), 1) {
    ast-value False
}

multi method optimize(Red::AST $left, Red::AST $right where compare($left, $_), 1) {
    $left
}

#| x > 1 AND x > 10 ==> x > 10
multi method optimize(GeGt $left, GeGt $right, 1) {
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

#| x < 1 AND x < 10 ==> x < 1
multi method optimize(LeLt $left, LeLt $right, 1) {
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

#| x > 10 AND x < 1 ==> False
multi method optimize(GeGt $left, LeLt $right, 1) {
    my $lv = $left.args.first(*.^can: "get-value").get-value;
    my $rv = $right.args.first(*.^can: "get-value").get-value;
    return ast-value False if $lv.defined and $rv.defined and $lv > $rv
}

#| x < 1 AND x > 10 ==> False
multi method optimize(LeLt $left, GeGt $right, 1) {
    my $lv = $left.args.first(*.^can: "get-value").get-value;
    my $rv = $right.args.first(*.^can: "get-value").get-value;
    return ast-value False if $lv.defined and $rv.defined and $lv < $rv
}

#| a.b AND NOT(a.b) ==> True
multi method optimize(Red::Column $left, Red::AST::Not $right, 1) {
    return ast-value True if compare $left, $right.value
}

#| NOT(a.b) AND a.b ==> True
multi method optimize(Red::AST::Not $left, Red::Column $right, 1) {
    self.optimize: $right, $left, 1
}

multi method optimize($, $, $) {}

multi method optimize(AstFalse, Red::AST $)  { ast-value False }
multi method optimize(Red::AST $, AstFalse)  { ast-value False }

multi method optimize(AstTrue, Red::AST $right) { $right }
multi method optimize(Red::AST $left, AstTrue)  { $left  }

multi method optimize(Red::AST $left is copy, Red::AST $right is copy) {
    my $lcols = set $left.find-column-name;
    my $rcols = set $right.find-column-name;

    $left  .= value if $left ~~ Red::AST::So;
    $right .= value if $right ~~ Red::AST::So;

    my $cols = ($lcols ∩ $rcols).elems;
    .return with self.optimize: $left, $right, $cols
}
