use Red::AST;
unit class Red::AST::DropTable does Red::AST;

has Str                     $.name;

method returns { Nil }
