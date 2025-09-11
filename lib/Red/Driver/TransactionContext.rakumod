use Red::Driver;
use Red::AST::Savepoint;
use Red::AST::RollbackToSavepoint;
use Red::AST::ReleaseSavepoint;
use Red::AST::BeginTransaction;
use Red::AST::CommitTransaction;
use Red::AST::RollbackTransaction;

#| Transaction context that manages savepoints on a shared connection
unit class Red::Driver::TransactionContext does Red::Driver;

has Red::Driver $.parent is required;
has Int         $.level is required;
has Str         $.savepoint-name;
has Promise     $.promise .= new;

submethod TWEAK() {
    # Start the main transaction or create a savepoint
    if $!level == 1 {
        # Start main transaction
        $!parent.prepare(Red::AST::BeginTransaction.new).map: *.execute;
    } elsif $!savepoint-name.defined {
        # Create savepoint
        $!parent.prepare(Red::AST::Savepoint.new(:name($!savepoint-name))).map: *.execute;
    }
}

method new-connection {
    # For nested transactions, create another savepoint context
    my $new-level = $!level + 1;
    my $new-name = "sp{$new-level}";
    Red::Driver::TransactionContext.new(
        :parent($!parent),
        :level($new-level),
        :savepoint-name($new-name)
    )
}

# Delegate most methods to the parent connection
method prepare($query) { $!parent.prepare($query) }
method execute($query, *@bind) { $!parent.execute($query, |@bind) }
method schema-reader { $!parent.schema-reader }
method translate($ast, $context?) { $!parent.translate($ast, $context) }
method default-type-for($column) { $!parent.default-type-for($column) }
method is-valid-table-name($name) { $!parent.is-valid-table-name($name) }
method type-by-name($name) { $!parent.type-by-name($name) }
method map-exception($exception) { $!parent.map-exception($exception) }
method inflate($value, *%args) { $!parent.inflate($value, |%args) }
method optimize($ast) { $!parent.optimize($ast) }
method debug(*@args) { $!parent.debug(|@args) }
method events { $!parent.events }
method emit($data) { $!parent.emit($data) }
method auto-register() { $!parent.auto-register() }
method should-drop-cascade() { $!parent.should-drop-cascade() }

# Override transaction methods for savepoint behavior
method begin {
    self.new-connection
}

method commit {
    if $!level > 1 && $!savepoint-name.defined {
        # We're in a savepoint, release it
        $!parent.prepare(Red::AST::ReleaseSavepoint.new(:name($!savepoint-name))).map: *.execute;
        $!promise.keep;
    } elsif $!level == 1 {
        # We're in the main transaction, commit it
        $!parent.prepare(Red::AST::CommitTransaction.new).map: *.execute;
        $!promise.keep;
    }
    self
}

method rollback {
    if $!level > 1 && $!savepoint-name.defined {
        # We're in a savepoint, rollback to it
        $!parent.prepare(Red::AST::RollbackToSavepoint.new(:name($!savepoint-name))).map: *.execute;
        $!promise.break("Transaction rolled back");
    } elsif $!level == 1 {
        # We're in the main transaction, rollback it
        $!parent.prepare(Red::AST::RollbackTransaction.new).map: *.execute;
        $!promise.break("Transaction rolled back");
    }
    self
}