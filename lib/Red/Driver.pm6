use Red::AST;
unit role Red::Driver;

method translate(Red::AST)  { ... }
method prepare(Str)         { ... }

method optimize(Red::AST $in) { $in }
