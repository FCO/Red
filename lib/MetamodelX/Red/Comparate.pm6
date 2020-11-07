use Red::Model;
use Red::AST::Value;
use Red::Attr::Column;

=head2 MetamodelX::Red::Comparate

unit role MetamodelX::Red::Comparate;
has SetHash $!added-method .= new;

#| An internal method that generates Red getters and setters for an
#| attribute $attr of a type.
method add-comparate-methods(::Type Mu:U \type, Red::Attr::Column $attr is copy --> Empty) {
    $attr .= clone: :package(type);
    unless $!added-method{"{ type.^name }|$attr"} {
	#say type.^name, " - ", $attr.package.^name;
	use MONKEY-SEE-NO-EVAL;
	my $proto = EVAL "my proto method { $attr.name.substr(2) }( Red::Model: ) \{*}";
	no MONKEY-SEE-NO-EVAL;
	#dd $proto;
	type.^add_method: $attr.name.substr(2), $proto;
        if $attr.rw {
            type.^add_multi_method: $attr.name.substr(2), my method (Mu:U:) is rw {
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
            type.^add_multi_method: $attr.name.substr(2), my method (Mu:U:) {
		#say type.^name, " - ", $attr.package.^name;
                $attr.column
            }
        }
        $!added-method{"{ type.^name }|$attr"}++
    }
}
