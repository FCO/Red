use Red::AST;
unit role Red::Driver;

method translate(Red::AST, $?)  { ... }
multi method prepare(Str)       { ... }
multi method prepare(Red::AST)  { ... }

method execute($query, *@bind) {
    self.prepare($query).execute: |@bind;
    self
}

method optimize(Red::AST $in) { $in }
