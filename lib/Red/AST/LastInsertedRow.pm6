use Red::AST;
use Red::Model;
unit class Red::AST::LastInsertedRow does Red::AST;

has Mu:U $.of;

method returns { Red::Model }
method args { $!of }

method new($of) { ::?CLASS.bless: :$of }
