use Red::AST::Infix;
unit class Red::AST::JsonItemOnKey does Red::AST::Infix;

has Str $.op = "->";

method returns {}