use Red::AST;
use Red::Column;
use Red::AST::Constraints;
unit class Red::AST::CreateTable does Red::AST;

has Str                     $.name;
has Red::Column             @.columns;
has Red::AST::Constraint    @.constraints;

method returns { Nil }
method args { |@!columns }
method find-column-name {}
