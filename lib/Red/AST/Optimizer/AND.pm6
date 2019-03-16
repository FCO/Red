use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;

unit role Red::AST::Optimizer::AND;

#| x > 1 AND x > 10 ==> x > 10
multi method optimize(
    $left  where Red::AST::Ge|Red::AST::Gt,
    $right where Red::AST::Ge|Red::AST::Gt,
    1
) {
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
multi method optimize(
    $left  where Red::AST::Le|Red::AST::Lt,
    $right where Red::AST::Le|Red::AST::Lt,
    1
) {
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
multi method optimize(
    $left  where Red::AST::Ge|Red::AST::Gt,
    $right where Red::AST::Le|Red::AST::Lt,
    1
) {
    my $lv = $left.args.first(*.^can: "get-value").get-value;
    my $rv = $right.args.first(*.^can: "get-value").get-value;
    return ast-value False if $lv.defined and $rv.defined and $lv > $rv
}

#| x < 1 AND x > 10 ==> False
multi method optimize(
    $left  where Red::AST::Le|Red::AST::Lt,
    $right where Red::AST::Ge|Red::AST::Gt,
    1
) {
    my $lv = $left.args.first(*.^can: "get-value").get-value;
    my $rv = $right.args.first(*.^can: "get-value").get-value;
    return ast-value False if $lv.defined and $rv.defined and $lv < $rv
}

#| a.b AND NOT(a.b) ==> True
multi method optimize(
    $left  where Red::Column,
    $right where Red::AST::Not,
    1
) {
    return ast-value True if $left eqv $right.value
}

#| NOT(a.b) AND a.b ==> True
multi method optimize(
    $left  where Red::AST::Not,
    $right where Red::Column,
    1
) {
    self.optimize: $right, $left, 1
}

multi method optimize($, $, $) {}

multi method optimize(Red::AST::Value $ where .value === False, Red::AST $)  { ast-value False }
multi method optimize(Red::AST $, Red::AST::Value $ where .value === False)  { ast-value False }

multi method optimize(Red::AST::Value $ where .value === True, Red::AST $right) { $right }
multi method optimize(Red::AST $left, Red::AST::Value $ where .value === True)  { $left  }

multi method optimize(Red::AST $left is copy, Red::AST $right is copy) {
    my $lcols = set $left.find-column-name;
    my $rcols = set $right.find-column-name;

    $left  .= value if $left ~~ Red::AST::So;
    $right .= value if $right ~~ Red::AST::So;

    my $cols = ($lcols ∩ $rcols).elems;
    .return with self.optimize: $left, $right, $cols
}