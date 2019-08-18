use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::AST::Optimizer::OR;

my subset AstFalse of Red::AST::Value where { .value === False };
my subset AstTrue  of Red::AST::Value where { .value === True  };

my subset GeGt of Red::AST::Infix where Red::AST::Ge|Red::AST::Gt;
my subset LeLt of Red::AST::Infix where Red::AST::Le|Red::AST::Lt;

multi infix:<eqv>(Red::AST::So $a, Red::AST $b) { $a.value eqv $b       }
multi infix:<eqv>(Red::AST $a, Red::AST::So $b) { $a       eqv $b.value }

multi method optimize(
        Red::AST::AND $left,
        Red::AST::AND $right where {$left.?left eqv $right.?left.not && $left.?right eqv $right.?right},
        $ where * > 0,
        ) {
            $right.right
}

multi method optimize(
        Red::AST::AND $left,
        Red::AST::AND $right where {$left.?left eqv $right.?right.not && $left.?right eqv $right.?left},
        $ where * > 0,
        ) {
    $right.left
}

multi method optimize(
        Red::AST::AND $left,
        Red::AST::AND $right where {$left.?right eqv $right.?left.not && $left.?left eqv $right.?right},
        $ where * > 0,
        ) {
    $right.right
}

multi method optimize(
        Red::AST::AND $left,
        Red::AST $right where { $left.left eqv $right.not },
        $,
        ) {
    Red::AST::OR.new: $left.right, $right
}

multi method optimize(
        Red::AST::AND $left,
        Red::AST $right where { $left.right eqv $right.not },
        $,
        ) {
    Red::AST::OR.new: $left.left, $right
}

multi method optimize(
        Red::AST $left,
        Red::AST::AND $right where { $right.left eqv $left.not },
        $,
        ) {
    Red::AST::OR.new: $left, $right.right
}

multi method optimize(
        Red::AST $left,
        Red::AST::AND $right where { $right.right eqv $left.not },
        $,
        ) {
    Red::AST::OR.new: $left, $right.left
}

#| x > 1 OR x > 10 ==> x > 10
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

#| x < 1 OR x < 10 ==> x < 1
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

#| x < 10 OR x > 1 ==> True
multi method optimize(LeLt $left, GeGt $right, 1) {
    my $lv = $left.args.first(*.^can: "get-value").get-value;
    my $rv = $right.args.first(*.^can: "get-value").get-value;
    return ast-value True if $lv.defined and $rv.defined and $lv > $rv
}

#| x > 1 OR x < 10 ==> True
multi method optimize(GeGt $left, LeLt $right, 1) {
    self.optimize: $right, $left, 1
}

#| a.b OR NOT(a.b) ==> True
multi method optimize($left where Red::Column, $right where Red::AST::Not, 1) {
    return ast-value True if $left eqv $right.value
}

#| NOT(a.b) AND a.b ==> True
multi method optimize($left where Red::AST::Not, $right where Red::Column, 1) {
    self.optimize: $right, $left, 1
}

multi method optimize($, $, $) {}

multi method optimize(AstTrue, Red::AST $)  { ast-value True }
multi method optimize(Red::AST $, AstTrue)  { ast-value True }

multi method optimize(AstFalse, Red::AST $right) { $right }
multi method optimize(Red::AST $left, AstFalse)  { $left  }

multi method optimize(Red::AST $left is copy, Red::AST $right is copy) {
    my $lcols = set $left.find-column-name;
    my $rcols = set $right.find-column-name;

    $left  .= value if $left ~~ Red::AST::So;
    $right .= value if $right ~~ Red::AST::So;

    my $cols := ($lcols ∩ $rcols).elems;

    .return with self.optimize: $left, $right, $cols
}
