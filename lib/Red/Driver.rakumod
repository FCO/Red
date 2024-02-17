use Red::AST;
use Red::Column;
use Red::SchemaReader;
use X::Red::Exceptions;
use Red::Class;
use Red::Event;
use Red::AST::BeginTransaction;
use Red::AST::CommitTransaction;
use Red::AST::RollbackTransaction;

=head2 Red::Driver

#| Base role for a Red::Driver::*
unit role Red::Driver;

has Supplier $!supplier .= new;
#| Supply of events of that driver
has Supply   $.events    = $!supplier.Supply;

method new-connection {
    self.WHAT.new: |self.^attributes.map({ .name.substr(2) => .get_value: self }).Hash
}

#| Begin transaction
method begin {
    my $trans = self.new-connection;
    $trans.prepare(Red::AST::BeginTransaction.new).map: *.execute;
    $trans
}

#| Commit transaction
method commit {
    #die "Not in a transaction!" unless $*RED-TRANSACTION-RUNNING;
    self.prepare(Red::AST::CommitTransaction.new).map: *.execute;
    self
}

#| Rollback transaction
method rollback {
    #die "Not in a transaction!" unless $*RED-TRANSACTION-RUNNING;
    self.prepare(Red::AST::RollbackTransaction.new).map: *.execute;
    self
}

#| Self-register its events on Red.events
method auto-register(|) {
    Red::Class.instance.register-supply: $!events;
    self
}

#| Emit events
multi method emit($data?) {
    self.emit:
            Red::Event.new:
                    :db(self),
                    :db-name(self.^name),
                    :$data,
                    |(:metadata($_) with %*RED-METADATA)
}

#| Does this driver accept drop table cascade?
multi method should-drop-cascade { True }

#| Emit events
multi method emit(Red::Event $event) {
    $!supplier.emit:
            $event.clone:
                    :db(self),
                    :db-name(self.^name),
                    |(:db-name($_) with $*RED-DO-WITH),
                    |(:metadata($_) with %*RED-METADATA),
}

method schema-reader(--> Red::SchemaReader)             { ... }
method translate(Red::AST, $?)                          { ... }
multi method prepare(Str)                               { ... }
multi method default-type-for(Red::Column $ --> Str:D)  { ... }

#| Prepares a DB statement
multi method prepare(Red::AST $query) {
    note $query if $*RED-DEBUG-AST;
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

#| Checks if a name is a valid table name
multi method is-valid-table-name(Str --> Bool)          { True }

#| Maps types
multi method type-by-name("varchar" --> "varchar(255)") {}
#| Maps types
multi method type-by-name("string" --> "text")          {}
#| Maps types
multi method type-by-name("int"    --> "integer")       {}

#| Maps exception
multi method map-exception($orig-exception) {
    X::Red::Driver::Mapped::UnknownError.new: :$orig-exception
}

multi method prepare("") {class :: { method execute(|) {} }}

#| Default inflator
multi method inflate(Any $value, Any :$to) { $value }

#| Execute query
method execute($query, *@bind) {
    my @stt = self.prepare($query);
    (.execute: |@bind.map: { self.deflate: $_ } for @stt).tail
}

#| Optimize AST
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
