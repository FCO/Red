use Red::Model;
use Red::Attr::Column;
unit role MetamodelX::Red::Comparate;

method add-comparate-methods(Mu:U \type, Red::Attr::Column $attr) {
	my $name = $attr.column.attr-name;
    my \column = $attr.column.clone: :class(type);
    type.^add_multi_method: $name, method (Mu:U:) {
        column
    }
}

