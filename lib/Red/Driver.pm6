use Red::AST;
unit role Red::Driver;

method dbh                  { ... }
method translate(Red::AST)  { ... }

method optimize(Red::AST $in) { $in }
