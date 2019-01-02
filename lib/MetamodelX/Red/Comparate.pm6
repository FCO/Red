use Red::Model;
use Red::AST::Value;
use Red::Attr::Column;
unit role MetamodelX::Red::Comparate;
has SetHash $!added-method;

method add-comparate-methods(Mu:U \type, Red::Attr::Column $attr) {
    unless $!added-method{$attr} {
        my $name = $attr.column.attr-name;
        my \column = $attr.column.clone: :class(type);
        if $attr.rw {
            type.^add_multi_method: $name, method (Mu:U:) is rw {
                Proxy.new:
                FETCH => -> $ { column },
                STORE => -> $, $value {
                    %*UPDATE{column.name} = ast-value $value
                }
                ;
            }
        } else {
            type.^add_multi_method: $name, method (Mu:U:) {
                column
            }
            $!added-method{$attr}++
        }
    }
}
