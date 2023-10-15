use Red::Model;
use Red::AST::Value;
use Red::Attr::Column;

=head2 MetamodelX::Red::Comparate

unit role MetamodelX::Red::Comparate;
has SetHash $!added-method .= new;

#| An internal method that generates Red getters and setters for an
#| attribute $attr of a type.
method add-comparate-methods(Mu:U \type, Red::Attr::Column $attr --> Empty) {
    unless $!added-method{"{ type.^name }|$attr"} {
        if $attr.rw {
            type.^add_multi_method: $attr.name.substr(2), method (Mu:U:) is rw {
                die "Cannot look up attributes in a { type.^name } type object" without $*RED-INTERNAL;
                Proxy.new:
                FETCH => -> $ { $attr.column },
                STORE => -> $, $value {
                    my &deflator = $attr.column.deflate;
                    my $val = do given $value {
                        when Red::AST { $_ }
                        default {
                            ast-value .&deflator, :type($attr.type)
                        }
                    }
                    @*UPDATE.push: Pair.new: $attr.column, $val
                },
            }
        } else {
            type.^add_multi_method: $attr.name.substr(2), method (Mu:U:) {
                die "Cannot look up attributes in a { type.^name } type object" without $*RED-INTERNAL;
                $attr.column
            }
        }
        $!added-method{"{ type.^name }|$attr"}++
    }
}
