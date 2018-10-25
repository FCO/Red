use Red::AST;
use Red::Model;
unit role Red::ResultAssociative[Red::Model $of, Red::AST $key-of] does Associative;

has Red::AST    $!key-of = $key-of;
has Red::AST    $.filter;
has             $.rs is required;

method of     { $of }
method key-of { $!key-of.returns }

method keys {
    $!rs.create-map: $key-of, :group($key-of)
}
