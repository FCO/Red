use Red::AST;
unit class Red::AST::Function does Red::AST;

has Mu  @.args;
has Str $.func;

method args { |@!args }

