use Red::AST;

#| An internal field transported across a SELECT boundary.
unit class Red::AST::ProjectionField does Red::AST;

has Red::AST $.value is required;
has Str $.name is required;

method returns { $!value.returns }
method args { $!value }
method find-column-name { $!name }
