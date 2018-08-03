use v6.d.PREVIEW;
use Red::ResultSet;
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
        self.Metamodel::ClassHOW::compose(type);
        for type.^attributes.grep: Red::Column:D -> Red::Column:D $column {
            %!columns ∪= $column;
            %!attr-to-column{$column.name} = $column.column-name
        }
        self.add_role: type, Red::ResultSet;
        type.^compose-columns
    }

    method compose-columns(\type) {
        for type.^columns.keys.grep(*.has_accessor).flatmap: { $_, type.^lookup(.name.substr: 2) } -> Attribute $attr, &meth {
            my \meta = self;
            &meth.wrap: method () is rw {
                my \obj = self;
                Proxy.new:
                    FETCH => method {
                        $attr.get_value: obj
                    },
                    STORE => method (\value) {
                        meta.dirty-cols ∪= $attr;
                        $attr.set_value: obj, value;
                    }
            }
        }
    }

    method is-dirty(Any:D \obj) { so self.dirty-cols }
    method clean-up(Any:D \obj) { self.dirty-cols = set() }
    method dirty-columns(|)     { self.dirty-cols }

    method add-column($obj, Red::Column $col) {
        $obj.columns: $obj.columns ∪ $col
    }
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
    $attr does Red::Column;
    $attr.^attributes.first('$!column-name').set_value: $attr, %column<name> if %column<name>:exists;
    $attr.^attributes.first('$!is-id').set_value: $attr, %column<id> if %column<id>:exists;
}
