use Red::AST;
#| AST to rollback to a savepoint
unit class Red::AST::RollbackToSavepoint does Red::AST;

has Str $.name is required;

method args {}

method returns {}

method find-column-name {}