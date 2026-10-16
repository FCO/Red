use Red::Model;
use Red::AST::Value;
use Red::AST::Reference;
use Red::Attr::Column;

=head2 MetamodelX::Red::Comparate

unit role MetamodelX::Red::Comparate;
has SetHash $!added-method .= new;

#| An internal method that generates Red getters and setters for an
#| attribute $attr of a type.
method add-comparate-methods(::T Mu:U \type, Red::Attr::Column $attr --> Empty) {
    unless $!added-method{"{ type.^name }|$attr"} {
        if $attr.rw {
            type.^add_multi_method: $attr.name.substr(2), method (T:U:) is rw {
                die "Cannot look up attributes in a { type.^name } type object" without $*RED-INTERNAL;
                Proxy.new:
                FETCH => -> $ {
                    my $column = (type.^columns.first(*.name eq $attr.name) // $attr).column;
                    $column.computation ~~ Red::AST::Reference
                        ?? $column.computation.clone(:origin($column)) !! $column
                },
                STORE => -> $, $value {
                    my $column = (type.^columns.first(*.name eq $attr.name) // $attr).column;
                    my &deflator = $column.deflate;
                    my $val = do given $value {
                        when Red::AST { $_ }
                        default {
                            ast-value .&deflator, :type($attr.type)
                        }
                    }
                    @*UPDATE.push: Pair.new: $column, $val
                },
            }
        } else {
            type.^add_multi_method: $attr.name.substr(2), method (T:U:) {
                die "Cannot look up attributes in a { type.^name } type object" without $*RED-INTERNAL;
                my $column = (type.^columns.first(*.name eq $attr.name) // $attr).column;
                $column.computation ~~ Red::AST::Reference
                    ?? $column.computation.clone(:origin($column)) !! $column
            }
        }
        $!added-method{"{ type.^name }|$attr"}++
    }
}
