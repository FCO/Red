use Red::AST;

#| Releases a savepoint without committing the surrounding transaction
unit class Red::AST::ReleaseSavepoint does Red::AST;

has Str $.name is required;

method args { $!name }
method returns {}
method find-column-name {}
