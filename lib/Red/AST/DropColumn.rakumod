use Red::AST;

#| Represents an alter table drop column
unit class Red::AST::DropColumn does Red::AST;

has Str  $.table is required;
has Str  $.name  is required;

method find-column-name {}
method args {}
method returns {}
