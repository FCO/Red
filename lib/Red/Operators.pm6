use Red::AST;
use Red::AST::Infixes;
use Red::AST::Divisable;
use Red::AST::Value;
use Red::ResultSeq;

=head2 Red::Operators

unit module Red::Operators;

# TODO: Diferenciate prefix and postfix
#| --X
multi prefix:<-->(Red::Column $a) is export {
    @*UPDATE.push: $a => Red::AST::Sub.new: $a, ast-value 1;
    $a
}

#| ++X
multi prefix:<++>(Red::Column $a) is export {
    @*UPDATE.push: $a => Red::AST::Sum.new: $a, ast-value 1;
    $a
}

#| X--
multi postfix:<-->(Red::Column $a) is export {
    @*UPDATE.push: $a => Red::AST::Sub.new: $a, ast-value 1;
    $a
}

#| X++
multi postfix:<++>(Red::AST $a) is export {
    @*UPDATE.push: $a => Red::AST::Sum.new: $a, ast-value 1;
    $a
}

#| -X
multi prefix:<->(Red::AST $a) is export {
    Red::AST::Mul.new: ast-value(-1), $a
}

#| +X
multi prefix:<+>(Red::AST $a) is export {
    Red::AST::Mul.new: ast-value(1), $a
}

#| X + Y
multi infix:<+>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Sum.new: $a, $b
}

multi infix:<+>(Red::AST $a, Numeric() $b) is export {
    Red::AST::Sum.new: $a, ast-value $b
}

multi infix:<+>(Numeric() $a, Red::AST $b) is export {
    Red::AST::Sum.new: ast-value($a), $b
}

#| X - Y
multi infix:<->(Red::AST $a, Red::AST $b) is export {
    Red::AST::Sub.new: $a, $b
}

multi infix:<->(Red::AST $a, Numeric() $b) is export {
    Red::AST::Sub.new: $a, ast-value $b
}

multi infix:<->(Numeric() $a, Red::AST $b) is export {
    Red::AST::Sub.new: ast-value($a), $b
}

#| X * Y
multi infix:<*>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Mul.new: $a, $b
}

multi infix:<*>(Red::AST $a, Numeric() $b) is export {
    Red::AST::Mul.new: $a, ast-value $b
}

multi infix:<*>(Numeric() $a, Red::AST $b) is export {
    Red::AST::Mul.new: ast-value($a), $b
}

#| X / Y
multi infix:</>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Div.new: $a, $b
}

multi infix:</>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Div.new: $a, ast-value $b
}

multi infix:</>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Div.new: ast-value($a), $b
}

multi infix:</>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Div.new: $a, ast-value($b), :bind-right
}

multi infix:</>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Div.new: ast-value($a), $b, :bind-left
}

#| ==
multi infix:<==>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Eq.new: $a, $b, :cast<num>
}
multi infix:<==>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<==>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>
}
multi infix:<==>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<==>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>
}

#| !=
multi infix:<!=>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ne.new: $a, $b, :cast<num>
}
multi infix:<!=>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<!=>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>
}
multi infix:<!=>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<!=>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>
}

#| ==
#multi infix:<==>(Red::AST $a, Red::AST $b) is export {
#    Red::AST::Eq.new: $a, $b, :cast<num>
#}
multi infix:<==>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<==>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>
}
multi infix:<==>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<==>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>
}

#| !=
multi infix:<!=>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ne.new: $a, $b, :cast<num>
}
multi infix:<!=>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<!=>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>
}
multi infix:<!=>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<!=>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>
}

#| eq
multi infix:<eq>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<eq>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<str>
}
multi infix:<eq>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<eq>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<str>
}

#| ne
multi infix:<ne>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<ne>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<str>
}
multi infix:<ne>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<ne>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<str>
}

#| <
multi infix:<< < >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<num>
}
multi infix:<< < >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< < >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>
}
multi infix:<< < >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< < >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>
}

#| >
multi infix:<< > >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<num>
}
multi infix:<< > >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< > >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>
}
multi infix:<< > >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< > >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>
}

#| <=
multi infix:<< <= >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<num>
}
multi infix:<< <= >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< <= >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>
}
multi infix:<< <= >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< <= >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>
}

#| >=
multi infix:<< >= >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<num>
}
multi infix:<< >= >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< >= >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>
}
multi infix:<< >= >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< >= >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>
}

#| <
multi infix:<< < >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<num>
}
multi infix:<< < >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< < >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>
}
multi infix:<< < >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< < >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>
}

#| >
multi infix:<< > >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<num>
}
multi infix:<< > >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< > >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>
}
multi infix:<< > >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< > >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>
}

#| <=
multi infix:<< <= >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<num>
}
multi infix:<< <= >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< <= >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>
}
multi infix:<< <= >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< <= >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>
}

#| >=
multi infix:<< >= >>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<num>
}
multi infix:<< >= >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< >= >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>
}
multi infix:<< >= >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< >= >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>
}

#| lt
multi infix:<lt>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<str>
}
multi infix:<lt>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<lt>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<str>
}
multi infix:<lt>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<lt>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<str>
}

#| gt
multi infix:<gt>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<str>
}
multi infix:<gt>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<gt>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<str>
}
multi infix:<gt>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<gt>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<str>
}

#| le
multi infix:<le>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<str>
}
multi infix:<le>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<le>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<str>
}
multi infix:<le>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<le>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<str>
}

#| ge
multi infix:<ge>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<str>
}
multi infix:<ge>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<ge>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<str>
}
multi infix:<ge>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<ge>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<str>
}

#| %
multi infix:<%>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Mod.new: $a, $b, :cast<int>
}
multi infix:<%>(Red::AST $a, Int() $b is rw) is export {
    Red::AST::Mod.new: $a, ast-value($b), :cast<int>, :bind-right
}
multi infix:<%>(Red::AST $a, Int() $b is readonly) is export {
    Red::AST::Mod.new: $a, ast-value($b), :cast<int>
}
multi infix:<%>(Int() $a is rw, Red::AST $b) is export {
    Red::AST::Mod.new: ast-value($a), $b, :cast<int>, :bind-left
}
multi infix:<%>(Int() $a is readonly, Red::AST $b) is export {
    Red::AST::Mod.new: ast-value($a), $b, :cast<int>
}

#| %%
multi infix:<%%>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Divisable.new: $a, $b, :cast<int>
}
multi infix:<%%>(Red::AST $a, Int() $b is rw) is export {
    Red::AST::Divisable.new: $a, ast-value($b), :cast<int>, :bind-right
}
multi infix:<%%>(Red::AST $a, Int() $b is readonly) is export {
    Red::AST::Divisable.new: $a, ast-value($b), :cast<int>
}
multi infix:<%%>(Int() $a is rw, Red::AST $b) is export {
    Red::AST::Divisable.new: ast-value($a), $b, :cast<int>, :bind-left
}
multi infix:<%%>(Int() $a is readonly, Red::AST $b) is export {
    Red::AST::Divisable.new: ast-value($a), $b, :cast<int>
}

#| ~
multi infix:<~>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Concat.new: $a, $b, :cast<str>
}
multi infix:<~>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Concat.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<~>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Concat.new: $a, ast-value($b), :cast<str>
}
multi infix:<~>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Concat.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<~>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Concat.new: ast-value($a), $b, :cast<str>
}

#| not X
multi prefix:<not>(Red::AST $a is readonly) is export {
    Red::AST::Not.new: $a
}
multi prefix:<not>(Red::AST $a is rw) is export {
    Red::AST::Not.new: $a, :bind
}

multi prefix:<!>(Red::AST $a) is export {
    Red::AST::Not.new: $a
}

multi prefix:<not>(Red::AST::In $a) is export {
    $a.not;
}

#| !X
multi prefix:<!>(Red::AST::In $a) is export {
    $a.not;
}

#| so
multi prefix:<so>(Red::AST $a) is export {
    Red::AST::So.new: $a
}

#| ?X
multi prefix:<?>(Red::AST $a) is export {
    Red::AST::So.new: $a
}

#| AND
multi infix:<AND>(Red::AST $a, Red::AST $b) is export is tighter(&infix:<==>) {
    Red::AST::AND.new: $a, $b
}

#| OR
multi infix:<OR>(Red::AST $a, Red::AST $b) is export {
    Red::AST::OR.new: $a, $b
}

#| ∪
multi infix:<∪>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a (|) $b
}
#| (|)
multi infix:<(|)>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a.union: $b
}
#| ∩
multi infix:<∩>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a (&) $b
}
#| (&)
multi infix:<(&)>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a.intersect: $b
}
#| ⊖
multi infix:<⊖>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a (-) $b
}
#| (-)
multi infix:<(-)>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a.minus: $b
}

#| in
multi infix:<in>(Red::AST $a, Red::ResultSeq:D $b ) is export is default {
    Red::AST::In.new: $a, $b.ast(:sub-select);
}
#| ⊂
multi infix:<⊂>(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::In.new: $a, $b.ast(:sub-select);
}
#| (<)
multi infix:«(<)»(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::In.new: $a, $b.ast(:sub-select);
}
#| ⊃
multi infix:<⊃>(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::NotIn.new: $a, $b.ast(:sub-select);
}
#| (>)
multi infix:«(>)»(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::NotIn.new: $a, $b.ast(:sub-select);
}

subset PositionalNotResultSeq of Any  where { $_ ~~ Positional && $_ !~~ Red::ResultSeq };

multi infix:<in>(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::In.new: $a, ast-value($b);
}

multi infix:<⊂>(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::In.new: $a, ast-value($b);
}
multi infix:«(<)»(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::In.new: $a, ast-value($b);
}

multi infix:<⊃>(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::NotIn.new: $a, ast-value($b);
}
multi infix:«(>)»(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::NotIn.new: $a, ast-value($b);
}


multi infix:<in>(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::In.new: $a, $b.as-sub-select;
}

multi infix:<⊂>(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::In.new: $a, $b.as-sub-select;
}
multi infix:«(<)»(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::In.new: $a, $b.as-sub-select;
}

multi infix:<⊃>(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::NotIn.new: $a, $b.as-sub-select;
}
multi infix:«(>)»(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::NotIn.new: $a, $b.as-sub-select;
}

