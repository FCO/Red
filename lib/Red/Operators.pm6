use Red::Column;
use Red::Filter;
unit module Red::Operators;

multi infix:<==>(Red::Column $a, Numeric() $b is rw)          is export {
    Red::Filter.new: :op(Red::Op::eq), :args($a.cast("num"), * ), :bind($b<>,)
}
multi infix:<==>(Red::Column $a, Numeric() $b is readonly)    is export {
    Red::Filter.new: :op(Red::Op::eq), :args($a.cast("num"), $b), :bind(   )
}
multi infix:<==>(Numeric() $a is rw, Red::Column $b)          is export {
    Red::Filter.new: :op(Red::Op::eq), :args(* , $b.cast("num")), :bind($a<>,)
}
multi infix:<==>(Numeric() $a is readonly, Red::Column $b)    is export {
    Red::Filter.new: :op(Red::Op::eq), :args($a<>, $b.cast("num")), :bind(   )
}

multi infix:<!=>(Red::Column $a, Numeric() $b is rw)          is export {
    Red::Filter.new: :op(Red::Op::ne), :args($a.cast("num"), * ), :bind($b<>,)
}
multi infix:<!=>(Red::Column $a, Numeric() $b is readonly)    is export {
    Red::Filter.new: :op(Red::Op::ne), :args($a.cast("num"), $b), :bind(   )
}
multi infix:<!=>(Numeric() $a is rw, Red::Column $b)          is export {
    Red::Filter.new: :op(Red::Op::ne), :args(* , $b.cast("num")), :bind($a<>,)
}
multi infix:<!=>(Numeric() $a is readonly, Red::Column $b)    is export {
    Red::Filter.new: :op(Red::Op::ne), :args($a<>, $b.cast("num")), :bind(   )
}

