use Red::AST;
use Red::Column;
use Red::SchemaReader;
use X::Red::Exceptions;
unit role Red::Driver;

method schema-reader(--> Red::SchemaReader)             { ... }
method translate(Red::AST, $?)                          { ... }
multi method prepare(Str)                               { ... }
multi method default-type-for(Red::Column $ --> Str:D)  { ... }

multi method prepare(Red::AST $query) {
    do for |self.translate: self.optimize: $query -> Pair \data {
        my ($sql, @bind) := do given data { .key, .value }
        next unless $sql;
        do unless $*RED-DRY-RUN {
            my $stt = self.prepare: $sql;
            $stt.predefined-bind;
            $stt.binds = @bind.map: { self.deflate: $_ };
            $stt
        }
    }
}

multi method is-valid-table-name(Str --> Bool)          { True }

multi method type-by-name("string" --> "text")          {}
multi method type-by-name("int"    --> "integer")       {}

multi method map-exception($orig-exception) {
    X::Red::Driver::Mapped::UnknownError.new: :$orig-exception
}

multi method prepare("") {class :: { method execute(|) {} }}

multi method inflate(Any $value, Any :$to) { $value }

method execute($query, *@bind) {
    my @stt = self.prepare($query);
    (.execute: |@bind.map: { self.deflate: $_ } for @stt).tail
}

method optimize(Red::AST $in --> Red::AST) { $in }

multi method debug(@bind) {
    if $*RED-DEBUG {
        note "BIND: @bind.perl()";
    }
}

multi method debug($sql) {
    if $*RED-DEBUG {
        note "SQL : $sql";
    }
}

multi method debug($sql, @binds) {
    if $*RED-DEBUG {
        note "SQL : $sql";
        note "BIND: @binds.perl()";
    }
}
