use Red::Column;
use Red::AST::Infixes;
use Red::AST::Value;
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

#multi infix:<AND>(Red::AST $a, Red::AST $b) is export {
#    Red::AST::AND.new: $a, $b
#}
#
#multi infix:<OR>(Red::AST $a, Red::AST $b) is export {
#    Red::AST::OR.new: $a, $b
#}
