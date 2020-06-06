use Red::AST::Comment;
#| Represents a table comment
unit class Red::AST::TableComment is Red::AST::Comment;

has Str $.table is required;
