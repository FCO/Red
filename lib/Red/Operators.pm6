use Red::Column;
use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;
no precompilation;
unit module Red::Operators;

# ==
multi infix:<==>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Eq.new: $a, $b, :cast<num>
}
multi infix:<==>(Red::Column $a, Numeric() $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<==>(Red::Column $a, Numeric() $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>
}
multi infix:<==>(Numeric() $a is rw, Red::Column $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<==>(Numeric() $a is readonly, Red::Column $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>
}

# !=
multi infix:<!=>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Ne.new: $a, $b, :cast<num>
}
multi infix:<!=>(Red::Column $a, Numeric() $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<!=>(Red::Column $a, Numeric() $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>
}
multi infix:<!=>(Numeric() $a is rw, Red::Column $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<!=>(Numeric() $a is readonly, Red::Column $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>
}

# eq
multi infix:<eq>(Red::Column $a, Str() $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<eq>(Red::Column $a, Str() $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<str>
}
multi infix:<eq>(Str() $a is rw, Red::Column $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<eq>(Str() $a is readonly, Red::Column $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<str>
}

# ne
multi infix:<ne>(Red::Column $a, Str() $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<ne>(Red::Column $a, Str() $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<str>
}
multi infix:<ne>(Str() $a is rw, Red::Column $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<ne>(Str() $a is readonly, Red::Column $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<str>
}

# <
multi infix:<< < >>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<num>
}
multi infix:<< < >>(Red::Column $a, Numeric() $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< < >>(Red::Column $a, Numeric() $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>
}
multi infix:<< < >>(Numeric() $a is rw, Red::Column $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< < >>(Numeric() $a is readonly, Red::Column $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>
}

# >
multi infix:<< > >>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<num>
}
multi infix:<< > >>(Red::Column $a, Numeric() $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< > >>(Red::Column $a, Numeric() $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>
}
multi infix:<< > >>(Numeric() $a is rw, Red::Column $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< > >>(Numeric() $a is readonly, Red::Column $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>
}

# <=
multi infix:<< <= >>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Le.new: $a, $b, :cast<num>
}
multi infix:<< <= >>(Red::Column $a, Numeric() $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< <= >>(Red::Column $a, Numeric() $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>
}
multi infix:<< <= >>(Numeric() $a is rw, Red::Column $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< <= >>(Numeric() $a is readonly, Red::Column $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>
}

# >=
multi infix:<< >= >>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<num>
}
multi infix:<< >= >>(Red::Column $a, Numeric() $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>, :bind-right
}
multi infix:<< >= >>(Red::Column $a, Numeric() $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>
}
multi infix:<< >= >>(Numeric() $a is rw, Red::Column $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>, :bind-left
}
multi infix:<< >= >>(Numeric() $a is readonly, Red::Column $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>
}

# lt
multi infix:<lt>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<str>
}
multi infix:<lt>(Red::Column $a, Str() $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<lt>(Red::Column $a, Str() $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<str>
}
multi infix:<lt>(Str() $a is rw, Red::Column $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<lt>(Str() $a is readonly, Red::Column $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<str>
}

# gt
multi infix:<gt>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<str>
}
multi infix:<gt>(Red::Column $a, Str() $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<gt>(Red::Column $a, Str() $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<str>
}
multi infix:<gt>(Str() $a is rw, Red::Column $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<gt>(Str() $a is readonly, Red::Column $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<str>
}

# le
multi infix:<le>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Le.new: $a, $b, :cast<str>
}
multi infix:<le>(Red::Column $a, Str() $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<le>(Red::Column $a, Str() $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<str>
}
multi infix:<le>(Str() $a is rw, Red::Column $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<le>(Str() $a is readonly, Red::Column $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<str>
}

# ge
multi infix:<ge>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<str>
}
multi infix:<ge>(Red::Column $a, Str() $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<str>, :bind-right
}
multi infix:<ge>(Red::Column $a, Str() $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<str>
}
multi infix:<ge>(Str() $a is rw, Red::Column $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<str>, :bind-left
}
multi infix:<ge>(Str() $a is readonly, Red::Column $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<str>
}

# *
multi infix:<*>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Mul.new: $a, $b, :cast<int>
}
multi infix:<*>(Red::Column $a, Int() $b is rw) is export {
    Red::AST::Mul.new: $a, ast-value($b), :cast<int>, :bind-right
}
multi infix:<*>(Red::Column $a, Int() $b is readonly) is export {
    Red::AST::Mul.new: $a, ast-value($b), :cast<int>
}
multi infix:<*>(Int() $a is rw, Red::Column $b) is export {
    Red::AST::Mul.new: ast-value($a), $b, :cast<int>, :bind-left
}
multi infix:<*>(Int() $a is readonly, Red::Column $b) is export {
    Red::AST::Mul.new: ast-value($a), $b, :cast<int>
}

# /
multi infix:</>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Div.new: $a, $b, :cast<int>
}
multi infix:</>(Red::Column $a, Int() $b is rw) is export {
    Red::AST::Div.new: $a, ast-value($b), :cast<int>, :bind-right
}
multi infix:</>(Red::Column $a, Int() $b is readonly) is export {
    Red::AST::Div.new: $a, ast-value($b), :cast<int>
}
multi infix:</>(Int() $a is rw, Red::Column $b) is export {
    Red::AST::Div.new: ast-value($a), $b, :cast<int>, :bind-left
}
multi infix:</>(Int() $a is readonly, Red::Column $b) is export {
    Red::AST::Div.new: ast-value($a), $b, :cast<int>
}

# %
multi infix:<%>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Mod.new: $a, $b, :cast<int>
}
multi infix:<%>(Red::Column $a, Int() $b is rw) is export {
    Red::AST::Mod.new: $a, ast-value($b), :cast<int>, :bind-right
}
multi infix:<%>(Red::Column $a, Int() $b is readonly) is export {
    Red::AST::Mod.new: $a, ast-value($b), :cast<int>
}
multi infix:<%>(Int() $a is rw, Red::Column $b) is export {
    Red::AST::Mod.new: ast-value($a), $b, :cast<int>, :bind-left
}
multi infix:<%>(Int() $a is readonly, Red::Column $b) is export {
    Red::AST::Mod.new: ast-value($a), $b, :cast<int>
}

# %%
multi infix:<%%>(Red::Column $a, Red::Column $b) is export {
    Red::AST::Divisable.new: $a, $b, :cast<int>
}
multi infix:<%%>(Red::Column $a, Int() $b is rw) is export {
    Red::AST::Divisable.new: $a, ast-value($b), :cast<int>, :bind-right
}
multi infix:<%%>(Red::Column $a, Int() $b is readonly) is export {
    Red::AST::Divisable.new: $a, ast-value($b), :cast<int>
}
multi infix:<%%>(Int() $a is rw, Red::Column $b) is export {
    Red::AST::Divisable.new: ast-value($a), $b, :cast<int>, :bind-left
}
multi infix:<%%>(Int() $a is readonly, Red::Column $b) is export {
    Red::AST::Divisable.new: ast-value($a), $b, :cast<int>
}

multi prefix:<not>(Red::AST $a) is export {
    Red::AST::Not.new: $a
}

multi prefix:<so>(Red::AST $a) is export {
    Red::AST::So.new: $a
}

multi infix:<AND>(Red::AST $a, Red::AST $b) is export is tighter(&infix:<==>) {
    Red::AST::AND.new: $a, $b
}

#multi infix:<OR>(Red::AST $a, Red::AST $b) is export {
#    Red::AST::OR.new: $a, $b
#}
