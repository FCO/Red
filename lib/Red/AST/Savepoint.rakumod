use Red::AST;

#| Marks a savepoint within a transaction
unit class Red::AST::Savepoint does Red::AST;

has Str $.name is required;

method args { $!name }
method returns {}
method find-column-name {}
