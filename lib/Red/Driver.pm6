use Red::AST;
unit role Red::Driver;

method translate(Red::AST)      { ... }
multi method prepare(Str)       { ... }
multi method prepare(Red::AST)  { ... }

method optimize(Red::AST $in) { $in }
