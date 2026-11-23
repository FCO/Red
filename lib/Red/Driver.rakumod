use Red::RowSecurity;
use Red::RowSecurity::Write;
use Red::RowSecurity::DDL;
use Red::RowSecurity::Statement;
use Red::RowSecurity::Context;
use Red::Driver::Migrations;
use X::Red::Migration;
use Red::AST;
use Red::QueryPlan;
use Red::Column;
use Red::SchemaReader;
use X::Red::Exceptions;
use Red::Class;
use Red::Event;
use Red::AST::BeginTransaction;
use Red::AST::CommitTransaction;
use Red::AST::RollbackTransaction;
use Red::AST::Savepoint;
use Red::AST::RollbackToSavepoint;
use Red::AST::ReleaseSavepoint;
use Red::Driver::Events;

=head2 Red::Driver

#| Base role for a Red::Driver::*
unit role Red::Driver does Red::Driver::Migrations does Red::Driver::Events;

has Supplier $!supplier .= new;
#| Supply of events of that driver
has Supply   $.events    = $!supplier.Supply;

#| Public backend name, independent of internal transaction wrappers.
method driver-name { self.^name }

#| Stable identity shared by a driver and the connection clones created by C<begin>.
method connection-id(--> Str:D) {
    my $delegate = self.^can('driver') ?? (try self.driver) !! Nil;
    return $delegate.connection-id if $delegate ~~ Red::Driver;

    my @volatile = <dbh supplier events table-formatter transaction-guard>;
    self.^name ~ '|' ~ self.^attributes
        .grep({ !@volatile.first(.name.substr(2)).defined })
        .map({ .name.substr(2) ~ '=' ~ .get_value(self).raku })
        .sort
        .join('|')
}

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

#| Creates a savepoint on the current connection
method savepoint(Str:D $name) {
    self.prepare(Red::AST::Savepoint.new(:$name)).map: *.execute;
    self
}

#| Rolls back to a savepoint, leaving it active
method rollback-to-savepoint(Str:D $name) {
    self.prepare(Red::AST::RollbackToSavepoint.new(:$name)).map: *.execute;
    self
}

#| Releases a savepoint without committing the surrounding transaction
method release-savepoint(Str:D $name) {
    self.prepare(Red::AST::ReleaseSavepoint.new(:$name)).map: *.execute;
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
                    :db-name(self.driver-name),
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
                    :db-name(self.driver-name),
                    |(:db-name($_) with $*RED-DO-WITH),
                    |(:metadata($_) with %*RED-METADATA),
}

method schema-reader(--> Red::SchemaReader)             { ... }
method translate(Red::AST, $?)                          { ... }
multi method prepare(Str)                               { ... }
multi method default-type-for(Red::Column $ --> Str:D)  { ... }

#| Prepares a DB statement
multi method prepare(Red::AST $query) {
    row-security-error('Structured DELETE requires model metadata; use textual SQL explicitly')
        if $query ~~ ::('Red::AST::Delete') && $query.model !~~ ::('Red::Model');
    row-security-error('Queries inside row policy methods are not supported')
        if DYNAMIC::<$*RED-ROW-POLICY-COMPILING>;
    if $query ~~ ::('Red::AST::CreateTable') && !$*RED-DRY-RUN {
        my $creation = row-creation-statement(self, $query);
        return $creation if $creation.DEFINITE;
    }
    my $protected = protected-row-query($query);
    if $protected && self.row-security-capabilities<native>
        && !self.?transaction-guard.DEFINITE && !$*RED-TRANSACTION-RUNNING {
        policy-context();
        return Red::RowSecurity::Statement.new(:driver(self), :$query,
            :row-context(row-security-context()));
    }
    my $secured = secure-row-query(self, $query);
    note $secured if $*RED-DEBUG-AST;
    do for |self.translate: self.optimize: $secured -> Pair:D $data {
        my ($sql, @bind) := ($data.key, $data.value);
        next unless $sql;
        do unless $*RED-DRY-RUN {
            my $stt = self.prepare: $sql;
            $stt.predefined-bind;
            $stt.binds = @bind.map: { self.deflate: $_ };
            $protected ?? $stt.row-context-bound(row-security-context()) !! $stt
        }
    }
}

# Drivers must explicitly opt in; wrappers delegate this contract.
method row-security-capabilities(--> Map:D) { Map.new }

method row-security-transaction-active(--> Bool:D) {
    so (self.?transaction-guard.DEFINITE || $*RED-TRANSACTION-RUNNING)
}

method prepare-row-security(@models) { }
method lock-row-security-write($query) { }
method row-security-check-suffix(--> Str:D) { '' }

method row-security-source-fields($model --> Str:D) { '*' }

method row-security-schema($model, %policies --> Array:D) {
    row-security-error('This driver cannot migrate row security policies')
        unless self.row-security-capabilities<filter>;
    []
}

method row-security-schema-change($old, $new --> Array:D) {
    []
}

method check-row-security-write($model) {
    row-security-error('This driver cannot validate row security write restrictions')
}

method supports-query-plans(--> Bool:D) { False }

#| Compile independently of the lifetime of a connection or statement.
method compile-query(Red::AST:D $query, :@parameters = [] --> Red::QueryPlan:D) {
    if $query ~~ ::('Red::AST::CreateTable') && self.row-security-capabilities<native> {
        row-security-error('Protected table DDL cannot be stored in a shared SQL plan')
            if row-protected(creation-row-model($query));
    }
    row-security-error('Protected queries cannot be stored in a shared SQL plan')
        if protected-row-query($query);
    row-security-error('Queries inside row policy methods are not supported')
        if DYNAMIC::<$*RED-ROW-POLICY-COMPILING>;
    Red::QueryPlan.compile(self, $query, :@parameters)
}

multi method prepare(Red::QueryPlan:D $plan, :@parameters = [], :@comments = []) {
    $plan.prepare(self, :@parameters, :@comments)
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
    row-security-error('Structured DELETE requires model metadata; use textual SQL explicitly')
        if $query ~~ ::('Red::AST::Delete') && $query.model !~~ ::('Red::Model');
    row-security-error('Queries inside row policy methods are not supported')
        if DYNAMIC::<$*RED-ROW-POLICY-COMPILING>;
    if $query ~~ Red::AST && protected-row-query($query)
        && $query ~~ ::('Red::AST::Insert') | ::('Red::AST::Update') | ::('Red::AST::Delete') {
        return execute-row-write(self, $query);
    }
    my @stt = self.prepare($query);
    (.execute: |@bind.map: { self.deflate: $_ } for @stt).tail
}

#| Optimize AST
method optimize(Red::AST $in --> Red::AST) { $in }

multi method debug(@bind) {
    if $*RED-DEBUG {
        note "BIND: @bind.raku()";
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
        note "BIND: @binds.raku()";
    }
}

#| Build the native client invocation for this backend.
method database-client(--> Hash) {
    X::Red::Migration.new(:reason('Native database client is unsupported')).throw
}

#| Synchronize generated identifiers after inserting explicit values.
method advance-sequences(@models) { Nil }

method normalize-index-expression($ast) { $ast }
method normalize-index-tokens(@tokens) { @tokens }

#| Release an executed cursor before ending its transaction.
method finish-statement($statement, Bool :$executed = False) {
    $statement.?finish if $executed
}

#| Physical integer spelling for the portable serial column abstraction.
multi method type-by-name("serial" --> Str:D) { self.default-type-for-type(Int) }

#| Create a database using backend-specific options.
method create-database(Str:D $name, *%options) {
    X::Red::Administration.new(
        :reason("Database creation is unsupported by {self.driver-name}")).throw
}

#| Create a login using backend-specific options.
method create-user(Str:D $name, *%options) {
    X::Red::Administration.new(
        :reason("User creation is unsupported by {self.driver-name}")).throw
}

#| Create a role using backend-specific options.
method create-role(Str:D $name, *%options) {
    X::Red::Administration.new(
        :reason("Role creation is unsupported by {self.driver-name}")).throw
}
