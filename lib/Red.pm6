use v6.d.PREVIEW;
use Red::Model;
use Red::AttrColumn;
use Red::Column;
use Red::Utils;

class MetamodelX::ResultSource is Metamodel::ClassHOW {
    has %!columns{Attribute};
    has %!attr-to-column;
    has %.dirty-cols is rw;

    method columns(|) is rw {
        %!columns
    }
    method attr-to-column(|) is rw {
        %!attr-to-column
    }
    method compose(Mu \type) {
        self.add_role: type, Red::Model;
        type.^compose-columns;
        self.add_role: type, role :: {
            method TWEAK(|) {
                self.^set-dirty: self.^columns
            }
        }
        self.Metamodel::ClassHOW::compose(type);
        for type.^attributes.grep: Red::AttrColumn:D -> Red::AttrColumn:D $column {
            %!attr-to-column{$column.name} = $column.column.name;
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
}

my package EXPORTHOW {
    package DECLARE {
        constant model = MetamodelX::ResultSource;
    }
}

multi trait_mod:<is>(Attribute $attr, Bool :$column!) is export {
    trait_mod:<is>($attr, :column{}) if $column
}

multi trait_mod:<is>(Attribute $attr, :%column!) is export {
    $attr does Red::AttrColumn;
    my $obj = Red::Column.new: |%column, :$attr;
    my \at = $attr.^attributes.first({ .name ~~ '$!column' });
    at.set_value: $attr, $obj;
}
