use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::Between;
use Red::Utils;

unit role Red::AST::Optimizer::AND;

=head2 Red::AST::Optimizer::AND

my subset AstFalse of Red::AST::Value where { .value === False };
my subset AstTrue  of Red::AST::Value where { .value === True  };

my subset GeGt of Red::AST::Infix where Red::AST::Ge|Red::AST::Gt;
my subset LeLt of Red::AST::Infix where Red::AST::Le|Red::AST::Lt;

#| 1 <= x <= 10
#| x >= 1 AND x <= 10 ==> x between 1 and 10
multi method optimize(
    Red::AST::Ge (
        Red::AST :left($big),
        Red::AST :right($columnl),
        |
    ),
    Red::AST::Ge (
        Red::AST :left($columnr),
        Red::AST :right($small),
        |
    ),
    1
) {
    nextsame unless compare $columnl, $columnr;
    Red::AST::Between.new: :comp($columnl), :args[$small, $big]
}

#| 10 >= x >= 1
#| x <= 10 AND x >= 1 ==> x between 1 and 10
multi method optimize(
    Red::AST::Le (
        Red::AST :left($small),
        Red::AST :right($columnl),
        |
    ),
    Red::AST::Le (
        Red::AST :left($columnr),
        Red::AST :right($big),
        |
    ),
    1
) {
    nextsame unless compare $columnl, $columnr;
    Red::AST::Between.new: :comp($columnl), :args[$small, $big]
}

multi method optimize(Red::AST $left, Red::AST $right where compare($left, .not), 1) {
    ast-value False
}

multi method optimize(Red::AST $left, Red::AST $right where compare($left, $_), 1) {
    $left
}

#| x > 1 AND x > 10 ==> x > 10
multi method optimize(
    GeGt $left (
        Red::AST :left($ll),
        Red::AST :right($lr),
        |
    ),
    GeGt $right (
        Red::AST :left($rl) where { compare $ll, $rl },
        Red::AST :right($rr),
        |
    ),
    $
) {
    my $lv = $lr.?get-value;
    my $rv = $rr.?get-value;
    if $lv.defined and $rv.defined {
        if $lv > $rv {
            return $left
        } elsif $lv < $rv {
            return $right
        }
    }
    nextsame
}

#| x < 1 AND x < 10 ==> x < 1
multi method optimize(
    LeLt $left (
        Red::AST :left($ll),
        Red::AST :right($lr),
        |
    ),
    LeLt $right (
        Red::AST :left($rl) where { compare $ll, $rl },
        Red::AST :right($rr),
        |
    ),
    $
) {
    my $lv = $lr.get-value;
    my $rv = $rr.get-value;
    if $lv.defined and $rv.defined {
        if $lv < $rv {
            return $left
        } elsif $lv > $rv {
            return $right
        }
    }
    nextsame
}

#| x > 10 AND x < 1 ==> False
multi method optimize(
    GeGt $left (
        Red::AST :left($ll),
        Red::AST :right($lr),
        |
    ),
    LeLt $right (
        Red::AST :left($rl) where { compare $ll, $rl },
        Red::AST :right($rr),
        |
    ),
    $
) {
    my $lv = $lr.get-value;
    my $rv = $rr.get-value;
    if $lv.defined and $rv.defined {
        return ast-value False if $lv > $rv;
    }
    nextsame
}

#| x < 1 AND x > 10 ==> False
multi method optimize(
    LeLt $left (
        Red::AST :left($ll),
        Red::AST :right($lr),
        |
    ),
    GeGt $right (
        Red::AST :left($rl) where { compare $ll, $rl },
        Red::AST :right($rr),
        |
    ),
    $
) {
    my $lv = $lr.get-value;
    my $rv = $rr.get-value;
    if $lv.defined and $rv.defined {
        return ast-value False if $lv < $rv;
    }
    nextsame
}

#| a.b AND NOT(a.b) ==> True
multi method optimize(Red::Column $left, Red::AST::Not $right where $left<> =:= $right.value<>, 1) {
    return ast-value False if compare $left, $right.value
}

#| NOT(a.b) AND a.b ==> True
multi method optimize(Red::AST::Not $left, Red::Column $right, 1) {
    self.optimize: $right, $left, 1
}

#| X AND NOT(X) => False
multi method optimize(Red::AST $left, Red::AST $right where compare($left, $right.not), 1) {
    return ast-value False
}

#| (X AND NOT(Y)) AND Y ==> False
multi method optimize(
    Red::AST::AND $left,
    Red::AST $right where $left.has-condition($right.not),
    1
) {
    return ast-value False
}

#| X AND (NOT(X) AND Y) ==> False
multi method optimize(
    Red::AST $left,
    Red::AST::AND $right where $right.has-condition($left.not),
    1
) {
    return ast-value False
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

multi method has-condition(Red::AST $cond where compare(any($.left, $.right), $cond)) { True }
multi method has-condition(Red::AST $cond where $.left  ~~ Red::AST::AND) { $.left.has-condition:  $cond }
multi method has-condition(Red::AST $cond where $.right ~~ Red::AST::AND) { $.right.has-condition: $cond }
multi method has-condition(Red::AST $) { False }
