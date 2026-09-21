use Red::AST;

#| Represents an alter table drop column
unit class Red::AST::DropTable does Red::AST;

has Str  $.table is required;

method find-column-name {}
method args {}
method returns {}
