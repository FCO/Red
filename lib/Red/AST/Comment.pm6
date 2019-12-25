use Red::AST;

#| Represents a comment
unit class Red::AST::Comment does Red::AST;

has Str $.msg;

method returns { }

method args { }

method find-column-name { }
