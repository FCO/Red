use Red::AST;

#| Represents a function call
unit class Red::AST::Between does Red::AST;

has Mu       @.args;
has Red::AST $.comp;
has Mu:U     $.returns;

method args { @!args }

method find-column-name { flat ($!comp, |@!args)>>.find-column-name }

