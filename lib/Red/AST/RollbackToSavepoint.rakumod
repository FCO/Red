use Red::AST;

#| Rolls back changes made after a savepoint
unit class Red::AST::RollbackToSavepoint does Red::AST;

has Str $.name is required;

method args { $!name }
method returns {}
method find-column-name {}
