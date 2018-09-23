use Red::AST;
use Red::Column;
unit class Red::AST::CreateTable does Red::AST;

has Str         $.name;
has Red::Column @.columns;

method args { |@!columns }
