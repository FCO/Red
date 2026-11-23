use Red::AST;
use Red::AST::Unary;

#| A private execution value. Always a bind, even when the Raku value is readonly.
unit class Red::AST::RowParameter does Red::AST;
has $.value is required;
method args { $!value }
method returns { $!value.WHAT }
method find-column-name { Nil }
method not { Red::AST::Not.new(self) }
