use Red::Column;
use Red::Filter;
unit module Red::Operators;

multi infix:<==>(Red::Column $a, $b is rw)          is export { Red::Filter.new: :op(Red::Op::eq), :args($a, * ), :bind($b,) }
multi infix:<==>(Red::Column $a, $b is readonly)    is export { Red::Filter.new: :op(Red::Op::eq), :args($a, $b), :bind(   ) }
multi infix:<==>($a is rw, Red::Column $b)          is export { Red::Filter.new: :op(Red::Op::eq), :args(* , $b), :bind($a,) }
multi infix:<==>($a is readonly, Red::Column $b)    is export { Red::Filter.new: :op(Red::Op::eq), :args($a, $b), :bind(   ) }

multi infix:<!=>(Red::Column $a, $b is rw)          is export { Red::Filter.new: :op(Red::Op::ne), :args($a, * ), :bind($b,) }
multi infix:<!=>(Red::Column $a, $b is readonly)    is export { Red::Filter.new: :op(Red::Op::ne), :args($a, $b), :bind(   ) }
multi infix:<!=>($a is rw, Red::Column $b)          is export { Red::Filter.new: :op(Red::Op::ne), :args(* , $b), :bind($a,) }
multi infix:<!=>($a is readonly, Red::Column $b)    is export { Red::Filter.new: :op(Red::Op::ne), :args($a, $b), :bind(   ) }

