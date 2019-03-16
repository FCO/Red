use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::AST::Optimizer::OR;

#| x > 1 OR x > 10 ==> x > 10
multi method optimization-col1(
    $left  where Red::AST::Ge|Red::AST::Gt,
    $right where Red::AST::Ge|Red::AST::Gt
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

#| x < 1 OR x < 10 ==> x < 1
multi method optimization-col1(
    $left  where Red::AST::Le|Red::AST::Lt,
    $right where Red::AST::Le|Red::AST::Lt
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

#| x < 10 OR x > 1 ==> True
multi method optimization-col1(
    $left  where Red::AST::Le|Red::AST::Lt,
    $right where Red::AST::Ge|Red::AST::Gt
) {
    my $lv = $left.args.first(*.^can: "get-value").get-value;
    my $rv = $right.args.first(*.^can: "get-value").get-value;
    return ast-value True if $lv.defined and $rv.defined and $lv > $rv
}

#| x > 1 OR x < 10 ==> True
multi method optimization-col1(
    $left  where Red::AST::Ge|Red::AST::Gt,
    $right where Red::AST::Le|Red::AST::Lt
) {
    self.optimization-col1: $right, $left
}

#| a.b OR NOT(a.b) ==> True
multi method optimization-col1(
    $left  where Red::Column,
    $right where Red::AST::Not
) {
    return ast-value True if $left eqv $right.value
}

#| NOT(a.b) AND a.b ==> True
multi method optimization-col1(
    $left  where Red::AST::Not,
    $right where Red::Column
) {
    self.optimization-col1: $right, $left
}

multi method optimization-col1($, $) {}

multi method optimize(Red::AST::Value $ where .value === True, Red::AST $)  { ast-value True }
multi method optimize(Red::AST $, Red::AST::Value $ where .value === True)  { ast-value True }

multi method optimize(Red::AST::Value $ where .value === False, Red::AST $right) { $right }
multi method optimize(Red::AST $left, Red::AST::Value $ where .value === False)  { $left  }

multi method optimize(Red::AST $left is copy, Red::AST $right is copy) {
    my $lcols = set $left.find-column-name;
    my $rcols = set $right.find-column-name;

    $left  .= value if $left ~~ Red::AST::So;
    $right .= value if $right ~~ Red::AST::So;

    my %cols := $lcols ∩ $rcols;
    if %cols == 1 {
        .return with self.optimization-col1: $left, $right
    }
}