use Red::AST;
unit role Red::Driver;

method translate(Red::AST, $?)              { ... }
multi method prepare(Str)                   { ... }
multi method prepare(Red::AST)              { ... }
multi method default-type-for($ --> Str:D)  { ... }

method execute($query, *@bind) {
    self.prepare($query).execute: |@bind;
    self
}

method optimize(Red::AST $in --> Red::AST) { $in }

multi method debug($sql) {
    if $*RED-DEBUG {
        note "SQL : $sql";
    }
}

multi method debug($sql, @binds) {
    if $*RED-DEBUG {
        note "SQL : $sql";
        note "BIND: @binds[]";
    }
}
