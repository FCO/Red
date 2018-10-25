use Red::AST;
unit class Red::AST::Function does Red::AST;

has Mu      @.args;
has Str     $.func;
has Mu:U    $.returns;

method args { |@!args }

