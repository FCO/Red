use Red::Column;
use Red::AST;
unit module Red::Operators;

# ==
multi infix:<==>(Red::Column $a, Red::Column $b)          is export {
    Red::AST.new: :op(Red::Op::eq), :args($a.cast("num"), $b.cast("num") ), :bind()
}
multi infix:<==>(Red::Column $a, Numeric() $b is rw)          is export {
    Red::AST.new: :op(Red::Op::eq), :args($a.cast("num"), * ), :bind($b<>,)
}
multi infix:<==>(Red::Column $a, Numeric() $b is readonly)    is export {
    Red::AST.new: :op(Red::Op::eq), :args($a.cast("num"), $b), :bind(   )
}
multi infix:<==>(Numeric() $a is rw, Red::Column $b)          is export {
    Red::AST.new: :op(Red::Op::eq), :args(* , $b.cast("num")), :bind($a<>,)
}
multi infix:<==>(Numeric() $a is readonly, Red::Column $b)    is export {
    Red::AST.new: :op(Red::Op::eq), :args($a<>, $b.cast("num")), :bind(   )
}

# !=
multi infix:<!=>(Red::Column $a, Red::Column $b)          is export {
    Red::AST.new: :op(Red::Op::ne), :args($a.cast("num"), $b.cast("num") ), :bind()
}
multi infix:<!=>(Red::Column $a, Numeric() $b is rw)          is export {
    Red::AST.new: :op(Red::Op::ne), :args($a.cast("num"), * ), :bind($b<>,)
}
multi infix:<!=>(Red::Column $a, Numeric() $b is readonly)    is export {
    Red::AST.new: :op(Red::Op::ne), :args($a.cast("num"), $b), :bind(   )
}
multi infix:<!=>(Numeric() $a is rw, Red::Column $b)          is export {
    Red::AST.new: :op(Red::Op::ne), :args(* , $b.cast("num")), :bind($a<>,)
}
multi infix:<!=>(Numeric() $a is readonly, Red::Column $b)    is export {
    Red::AST.new: :op(Red::Op::ne), :args($a<>, $b.cast("num")), :bind(   )
}

# eq
multi infix:<eq>(Red::Column $a, Str() $b is rw)          is export {
    Red::AST.new: :op(Red::Op::eq), :args($a.cast("str"), * ), :bind($b<>,)
}
multi infix:<eq>(Red::Column $a, Str() $b is readonly)    is export {
    Red::AST.new: :op(Red::Op::eq), :args($a.cast("str"), $b), :bind(   )
}
multi infix:<eq>(Str() $a is rw, Red::Column $b)          is export {
    Red::AST.new: :op(Red::Op::eq), :args(* , $b.cast("str")), :bind($a<>,)
}
multi infix:<eq>(Str() $a is readonly, Red::Column $b)    is export {
    Red::AST.new: :op(Red::Op::eq), :args($a<>, $b.cast("str")), :bind(   )
}

# ne
multi infix:<ne>(Red::Column $a, Str() $b is rw)          is export {
    Red::AST.new: :op(Red::Op::ne), :args($a.cast("str"), * ), :bind($b<>,)
}
multi infix:<ne>(Red::Column $a, Str() $b is readonly)    is export {
    Red::AST.new: :op(Red::Op::ne), :args($a.cast("str"), $b), :bind(   )
}
multi infix:<ne>(Str() $a is rw, Red::Column $b)          is export {
    Red::AST.new: :op(Red::Op::ne), :args(* , $b.cast("str")), :bind($a<>,)
}
multi infix:<ne>(Str() $a is readonly, Red::Column $b)    is export {
    Red::AST.new: :op(Red::Op::ne), :args($a<>, $b.cast("str")), :bind(   )
}

