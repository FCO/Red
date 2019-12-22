use Red::AST;

#| Represents a function call
unit class Red::AST::Function does Red::AST;

has Mu      @.args;
has Str     $.func;
has Mu:U    $.returns;

method args { |@!args }

method find-column-name { flat @!args>>.find-column-name }
