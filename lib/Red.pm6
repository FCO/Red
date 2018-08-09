use v6.d.PREVIEW;
use Red::Model;
use Red::AttrColumn;
use Red::Column;
use Red::Utils;
use Red::ResultSet;
use Red::DefaultResultSet;
use Red::AttrReferencedBy;
use Red::AttrQuery;
use Red::Filter;

class MetamodelX::Model is Metamodel::ClassHOW {
    has %!columns{Attribute};
    has %!attr-to-column;
    has %.dirty-cols is rw;
    has $.rs-class;

    method table(Mu \type) { camel-to-snake-case type.^name }
    method rs-class-name(Mu \type) { "{type.^name}::ResultSet" }
    method columns(|) is rw {
        %!columns
    }

    method id(Mu \type) {
        %!columns.keys.grep(*.column.id).list
    }

    method id-values(Red::Model:D $model) {
        self.id($model).map({ .get_value: $model }).list
    }

    method attr-to-column(|) is rw {
        %!attr-to-column
    }

    method compose(Mu \type) {
        if $.rs-class === Any {
            my $rs-class-name = $.rs-class-name(type);
            if try ::($rs-class-name) !~~ Nil {
                $!rs-class = ::($rs-class-name)
            } else {
                $!rs-class := Metamodel::ClassHOW.new_type: :name($rs-class-name);
                $!rs-class.^add_parent: Red::DefaultResultSet;
                $!rs-class.^add_method: "of", method { type }
                $!rs-class.^compose;
                type.WHO<ResultSet> := $!rs-class
            }
        }
        die "{$.rs-class.^name} should do the Red::ResultSet role" unless $.rs-class ~~ Red::ResultSet;
        self.add_role: type, Red::Model;
        type.^compose-columns;
        self.add_role: type, role :: {
            method TWEAK(|) {
                self.^set-dirty: self.^columns
            }
        }
        self.Metamodel::ClassHOW::compose(type);
        for type.^attributes -> $attr {
            %!attr-to-column{$attr.name} = $attr.column.name if $attr ~~ Red::AttrColumn:D;
        }
    }

    method add-column(Red::Model:U \type, Red::AttrColumn $attr) {
        %!columns ∪= $attr;
        my $name = $attr.name.substr: 2;
        type.^add_multi_method: $name, method (Red::Model:U:) {
            $attr.column
        }
        if $attr.has_accessor {
            if $attr.rw {
                type.^add_multi_method: $name, method () is rw {
                    my \obj = self;
                    Proxy.new:
                        FETCH => method {
                            $attr.get_value: obj
                        },
                        STORE => method (\value) {
                            return if value === $attr.get_value: obj;
                            obj.^set-dirty: $attr;
                            $attr.set_value: obj, value;
                        }
                    ;
                }
            } else {
                type.^add_multi_method: $name, method () {
                    $attr.get_value: self
                }
            }
        }
    }

    method compose-columns(Red::Model:U \type) {
        for type.^attributes.grep: Red::AttrColumn -> Red::AttrColumn $attr {
            type.^add-column: $attr
        }
    }

    method set-dirty($, $attr) {
        self.dirty-cols ∪= $attr;
    }
    method is-dirty(Any:D \obj) { so self.dirty-cols }
    method clean-up(Any:D \obj) { self.dirty-cols = set() }
    method dirty-columns(|)     { self.dirty-cols }
    method rs($)                { $.rs-class.new }
}

my package EXPORTHOW {
    package DECLARE {
        constant model = MetamodelX::Model;
    }
}

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

multi trait_mod:<is>(Attribute $attr, :&referenced-by!) is export {
    $attr does Red::AttrReferencedBy;
    $attr.wrap-data: &referenced-by
}

multi trait_mod:<is>(Attribute $attr, Str :$query!) is export {
    #TODO
    $attr does Red::AttrQuery;
    $attr.wrap-data: $query
}

multi infix:<==>(Red::Column $a, $b is rw)          is export { Red::Filter.new: :op(Red::Op::eq), :args($a, * ), :bind($b,) }
multi infix:<==>(Red::Column $a, $b is readonly)    is export { Red::Filter.new: :op(Red::Op::eq), :args($a, $b), :bind(   ) }
multi infix:<==>($a is rw, Red::Column $b)          is export { Red::Filter.new: :op(Red::Op::eq), :args(* , $b), :bind($a,) }
multi infix:<==>($a is readonly, Red::Column $b)    is export { Red::Filter.new: :op(Red::Op::eq), :args($a, $b), :bind(   ) }

multi infix:<!=>(Red::Column $a, $b is rw)          is export { Red::Filter.new: :op(Red::Op::ne), :args($a, * ), :bind($b,) }
multi infix:<!=>(Red::Column $a, $b is readonly)    is export { Red::Filter.new: :op(Red::Op::ne), :args($a, $b), :bind(   ) }
multi infix:<!=>($a is rw, Red::Column $b)          is export { Red::Filter.new: :op(Red::Op::ne), :args(* , $b), :bind($a,) }
multi infix:<!=>($a is readonly, Red::Column $b)    is export { Red::Filter.new: :op(Red::Op::ne), :args($a, $b), :bind(   ) }

