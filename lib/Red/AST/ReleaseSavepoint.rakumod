use Red::AST;
#| AST to release a savepoint
unit class Red::AST::ReleaseSavepoint does Red::AST;

has Str $.name is required;

method args {}

method returns {}

method find-column-name {}