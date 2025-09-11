use Red::AST;
#| AST to create a savepoint
unit class Red::AST::Savepoint does Red::AST;

has Str $.name is required;

method args {}

method returns {}

method find-column-name {}