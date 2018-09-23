use Red::AST;
unit class Red::AST::Select does Red::AST;

has Mu:U        $.of;
has Red::AST    $.filter;
has Int         $.limit;

method args { $!of, $!filter }
