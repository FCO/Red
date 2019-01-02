use Red::Model;
use Red::Attr::Column;
unit role MetamodelX::Red::Comparate;
has SetHash $!added-method;

method add-comparate-methods(::T Mu:U \type, Red::Attr::Column $attr) {
    unless $!added-method{$attr} {
        my $name = $attr.name.substr(2);
        T.^add_multi_method: $name, method (Mu:U:) {
            $attr.column
        }
        $!added-method{$attr}++
    }
}

