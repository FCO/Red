use Red::AST;
use Red::AST::Unary;

#| A symbolic context slot for portable policy snapshots; execution binds scalars.
unit class Red::AST::RowContext does Red::AST;
has Str $.key is required;
method args { $!key }
method returns { Any }
method find-column-name { Nil }
method not { Red::AST::Not.new(self) }
