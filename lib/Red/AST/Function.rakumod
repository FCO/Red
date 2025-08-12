use Red::AST;
use Red::AST::Unary;

#| Represents a function call
unit class Red::AST::Function does Red::AST;

has Mu      @.args;
has Str     $.func;
has Mu:U    $.returns;

method args { |@!args }

method find-column-name { flat @!args>>.find-column-name }

method not { Red::AST::Not.new: self }
