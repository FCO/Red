use Red::AST;
use Red::Column;
unit role Red::Driver;

method translate(Red::AST, $?)                          { ... }
multi method prepare(Str)                               { ... }
multi method prepare(Red::AST)                          { ... }
multi method default-type-for(Red::Column $ --> Str:D)  { ... }

multi method prepare("") {class :: { method execute(|) {} }}

multi method inflate(Any $value, Any :$to) { $value }

method execute($query, *@bind) {
    my $stt = self.prepare($query);
    $stt.execute: |@bind;
    $stt
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
