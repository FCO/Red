use Red::Column;
use Red::Filter;
use Red::AttrColumn;
use Red::ResultSet;

unit module Red::Traits;

multi infix:<==>(Red::Column $a, $b is rw)          is export { Red::Filter.new: :op(Red::Op::eq), :args($a, * ), :bind($b,) }
multi infix:<==>(Red::Column $a, $b is readonly)    is export { Red::Filter.new: :op(Red::Op::eq), :args($a, $b), :bind(   ) }
multi infix:<==>($a is rw, Red::Column $b)          is export { Red::Filter.new: :op(Red::Op::eq), :args(* , $b), :bind($a,) }
multi infix:<==>($a is readonly, Red::Column $b)    is export { Red::Filter.new: :op(Red::Op::eq), :args($a, $b), :bind(   ) }

multi infix:<!=>(Red::Column $a, $b is rw)          is export { Red::Filter.new: :op(Red::Op::ne), :args($a, * ), :bind($b,) }
multi infix:<!=>(Red::Column $a, $b is readonly)    is export { Red::Filter.new: :op(Red::Op::ne), :args($a, $b), :bind(   ) }
multi infix:<!=>($a is rw, Red::Column $b)          is export { Red::Filter.new: :op(Red::Op::ne), :args(* , $b), :bind($a,) }
multi infix:<!=>($a is readonly, Red::Column $b)    is export { Red::Filter.new: :op(Red::Op::ne), :args($a, $b), :bind(   ) }


multi trait_mod:<is>(Mu:U $model, Str:D :$rs-class!) {
    trait_mod:<is>($model, :rs-class(::($rs-class)))
}

multi trait_mod:<is>(Mu:U $model, Mu:U :$rs-class!) {
    die "{$rs-class.^name} should do the Red::ResultSet role" unless $rs-class ~~ Red::ResultSet;
    $model.HOW does role :: { method rs-class(|) { $rs-class<> } }
}

multi trait_mod:<is>(Attribute $attr, Bool :$column!) is export {
    trait_mod:<is>($attr, :column{}) if $column
}

multi trait_mod:<is>(Attribute $attr, :%column!) is export {
    $attr does Red::AttrColumn;
    my $class = $attr.package;
    my $obj = Red::Column.new: |%column, :$attr, :$class;
    my \at = $attr.^attributes.first({ .name ~~ '$!column' });
    at.set_value: $attr, $obj;
}

multi trait_mod:<is>(Mu:U $model, Str :$table! where .chars > 0) {
    $model.HOW does role :: {
        method table(|) { $table<> }
    }
}

#multi trait_mod:<is>(Attribute $attr, :&referenced-by!) is export {
#    $attr does Red::AttrReferencedBy;
#    $attr.wrap-data: &referenced-by
#}
#
#multi trait_mod:<is>(Attribute $attr, Str :$query!) is export {
#    #TODO
#    $attr does Red::AttrQuery;
#    $attr.wrap-data: $query
#}

