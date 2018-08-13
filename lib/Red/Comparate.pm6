use Red::Model;
use Red::AttrColumn;
unit role Red::Comparate;

method add-comparate-methods(Mu:U \type, Red::AttrColumn $attr) {
	my $name = $attr.column.attr-name;
    my \column = $attr.column.clone: :class(type);
    type.^add_multi_method: $name, method (Mu:U:) {
        column
    }
}

