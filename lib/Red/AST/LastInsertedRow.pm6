use Red::AST;
unit class Red::AST::LastInsertedRow does Red::AST;

has Mu:U $.of;

method args { $!of }

method new($of) { ::?CLASS.bless: :$of }
