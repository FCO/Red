use Red::Model;
use Red::AST::Value;
use Red::Attr::Column;
unit role MetamodelX::Red::Comparate;
has SetHash $!added-method .= new;

#| Creates methods to return columns
method add-comparate-methods(Mu:U \type, Red::Attr::Column $attr) {
    unless $!added-method{"{ type.^name }|$attr"} {
        if $attr.rw {
            type.^add_multi_method: $attr.name.substr(2), method (Mu:U:) is rw {
                Proxy.new:
                FETCH => -> $ { $attr.column },
                STORE => -> $, $value {
                    %*UPDATE{$attr.column.name} = ast-value $value
                }
                ;
            }
        } else {
            type.^add_multi_method: $attr.name.substr(2), method (Mu:U:) {
                $attr.column
            }
        }
        $!added-method{"{ type.^name }|$attr"}++
    }
}
