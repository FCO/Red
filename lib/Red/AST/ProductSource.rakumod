use Red::AST;

#| One independently scoped input of a Cartesian product.
unit class Red::AST::ProductSource does Red::AST;

has Red::AST $.row-policy;
has Str $.alias is required;
has Red::AST $.query;
has Mu $.model;
has @.rows;
has Str @.names;
has Mu @.types;

method args { () }
method returns { Any }
method find-column-name { Nil }
