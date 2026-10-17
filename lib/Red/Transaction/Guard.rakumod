use Red::Statement;
use X::Red::Exceptions;

#| Explicit lifetime control for a transaction or one of its savepoints.
unit class Red::Transaction::Guard;

my atomicint $savepoint-counter = 0;

# Keep the native driver/session, but attach a separate lifetime to each scope.
my role ScopedDriver {
    has Red::Transaction::Guard $.transaction-guard;

    method prepare(|c) {
        my $guard = $!transaction-guard;
        my &next = nextcallee;
        $guard.protect: {
            my \result = next(self, |c);
            given result {
                when Red::Statement { .guarded-by($guard) }
                when Iterable {
                    .map({ $_ ~~ Red::Statement ?? .guarded-by($guard) !! $_ }).eager
                }
                default { $_ }
            }
        }
    }

    method execute(|c) {
        my &next = nextcallee;
        $!transaction-guard.protect: { next(self, |c) }
    }

    method begin { $!transaction-guard.child.scoped-driver }

    method savepoint(|c) {
        my &next = nextcallee;
        $!transaction-guard.protect: { next(self, |c) }
    }

    method rollback-to-savepoint(|c) {
        my &next = nextcallee;
        $!transaction-guard.protect: { next(self, |c) }
    }

    method release-savepoint(|c) {
        my &next = nextcallee;
        $!transaction-guard.protect: { next(self, |c) }
    }

    method commit {
        $!transaction-guard.commit;
        self
    }

    method rollback {
        $!transaction-guard.rollback;
        self
    }

    method map-exception($exception) {
        $exception ~~ X::Red::Transaction ?? $exception !! callsame
    }

    # Keep the backend's public name while retaining the scoped driver in events.
    method driver-name { $!transaction-guard.driver-name }
}

# Structural typing avoids a circular dependency between the guard and drivers.
has Mu $!driver;
has Mu $!scoped-driver;
has Red::Transaction::Guard $!parent;
has Red::Transaction::Guard $!child;
has Str $!name;
has Str $!state = 'open';
has atomicint $!owner = 0;
has atomicint $!participants = 1;
has Bool $!participant-owner = False;
has Lock $!lifecycle-lock .= new;
has Lock::ConditionVariable $!available;
has Red::Statement @!statements;

submethod BUILD(Mu :$!driver!, Red::Transaction::Guard :$!parent, Str :$!name) {}

submethod TWEAK {
    $!available = $!lifecycle-lock.condition;
    $!scoped-driver = ($!driver but ScopedDriver).clone(:transaction-guard(self));
}

#| Internal driver used by ORM operations in this scope.
method scoped-driver { $!scoped-driver }

method driver-name { $!driver.^name }

#| Identity of the physical transaction shared by nested scopes.
method root { $!parent.defined ?? $!parent.root !! self }

# Reject competing database operations; participant changes wait for ownership.
# Reentry on the same thread is required by drivers which read back an inserted row during execution.
method !synchronize(&operation, Bool :$wait = False) {
    return $!parent!synchronize(&operation, :$wait) if $!parent.defined;
    my Int $owner = $*THREAD.id + 1;
    my Int $previous;
    my Bool $previous-participant;
    $!lifecycle-lock.protect: {
        while (⚛$!owner) != 0 && (⚛$!owner) != $owner {
            X::Red::Transaction.new(:reason('Concurrent access to a transaction')).throw
                unless $wait || $!participant-owner;
            $!available.wait;
        }
        $previous = ⚛$!owner;
        $previous-participant = $!participant-owner;
        $!participant-owner = $wait;
        atomic-assign($!owner, $owner);
    };
    {
        my Bool $released = False;
        my &release = {
            unless $released {
                $!lifecycle-lock.protect: {
                    $!participant-owner = $previous-participant;
                    atomic-assign($!owner, $previous);
                    $!available.signal_all;
                };
                $released = True;
            }
        };
        CATCH {
            default {
                release();
                .rethrow;
            }
        }
        LEAVE release();
        operation()
    }
}

#| Reserves a participant before scheduling work that uses this scope.
method retain {
    self!synchronize: :wait, {
        self!assert-open;
        ++⚛$!participants;
        self
    }
}

#| Releases one participant; the last rolls back an unfinished scope.
method release {
    self!synchronize: :wait, {
        X::Red::Transaction.new(:reason('Transaction has no remaining participants')).throw
            unless (⚛$!participants) > 0;
        self.rollback if --⚛$!participants == 0;
        self
    }
}

sub cleanup-and-rethrow(&cleanup, Exception:D $cause) {
    my Exception $error;
    try {
        cleanup();
        CATCH { default { $error = $_ } }
    }
    X::Red::Transaction::Cleanup.new(:$cause, :cleanup($error)).throw if $error.defined;
    $cause.rethrow;
}

# Runs with a participation already reserved by do or start.
method !invoke(&block) {
    my $guard = self;
    my $*RED-DB = $guard.scoped-driver;
    my $*RED-TRANSACTION-RUNNING = True;
    my $*RED-TRANSACTION-DB = $*RED-DB;
    LEAVE $guard.release;
    CATCH {
        default { cleanup-and-rethrow({ $guard.rollback }, $_) }
    }
    my %callbacks;
    for &block.signature.params -> $parameter {
        for $parameter.named_names -> $name {
            given $name {
                when 'commit' { %callbacks<commit> = { $guard.commit } }
                when 'rollback' { %callbacks<rollback> = { $guard.rollback } }
            }
        }
    }
    block(|%callbacks)
}

#| Executes a block synchronously with its own participation.
method do(&block) {
    self.retain;
    my \result = self!invoke(&block);
    X::Red::Transaction::AsyncResult.new.warn
        if result ~~ Promise:D && result.status == Planned;
    result
}

#| Reserves participation before scheduling a block; returns its Promise.
method start(&block) {
    my $guard = self;
    $guard.retain;
    {
        CATCH {
            default { cleanup-and-rethrow({ $guard.release }, $_) }
        }
        start { $guard!invoke(&block) }
    }
}

method !assert-open {
    X::Red::Transaction.new(:reason("Transaction scope is $!state")).throw
        unless $!state eq 'open';
}

#| Internal synchronization boundary for statements and ORM access.
method protect(&operation) {
    self!synchronize: {
        self!assert-open;
        X::Red::Transaction.new(:reason('A child transaction scope is still open')).throw
            if $!child.defined;
        operation()
    }
}

method assert-usable { self.protect: { True } }

method register-statement(Red::Statement:D $statement) {
    self.protect: { @!statements.push($statement) }
}

method !finish-statements {
    $!child!finish-statements if $!child.defined;
    my Exception $error;
    for @!statements -> $statement {
        try {
            $statement.finish-transaction;
            CATCH { default { $error //= $_ } }
        }
    }
    @!statements = ();
    $error.throw if $error.defined;
}

#| Opens a child savepoint on the reserved session.
method child {
    self.protect: {
        my Str $name = 'red_savepoint_' ~ ++⚛$savepoint-counter;
        $!driver.savepoint($name);
        $!child = self.WHAT.new(:driver($!driver), :parent(self), :$name);
        $!child
    }
}

method !invalidate(Str:D $state) {
    $!state = $state;
    $!child!invalidate($state) if $!child.defined;
    $!child = Red::Transaction::Guard;
}

method !detach {
    $!parent!remove-child if $!parent.defined;
}

method !remove-child { $!child = Red::Transaction::Guard }

method !abort(Exception:D $cause) {
    my Exception $cleanup;
    if $!parent.defined {
        try {
            self.root!rollback;
            CATCH { default { $cleanup = $_ } }
        }
    }
    self.root!invalidate('failed');
    X::Red::Transaction::Cleanup.new(:$cause, :$cleanup).throw if $cleanup.defined;
    $cause.rethrow;
}

method !rollback {
    my Exception $finish-error;
    try {
        self!finish-statements;
        CATCH { default { $finish-error = $_ } }
    }
    if $!parent.defined {
        $!driver.rollback-to-savepoint($!name);
        $!driver.release-savepoint($!name);
    } else {
        $!driver.rollback;
    }
    $finish-error.throw if $finish-error.defined;
}

#| Commits immediately, or releases this scope's savepoint.
method commit {
    self.protect: {
        CATCH {
            default {
                my $cause = $_;
                my Exception $cleanup;
                try {
                    self!rollback;
                    CATCH { default { $cleanup = $_ } }
                }
                self!abort(X::Red::Transaction::Cleanup.new(:$cause, :$cleanup))
                    if $cleanup.defined;
                self!invalidate('failed');
                self!detach;
                $cause.rethrow;
            }
        }
        self!finish-statements;
        if $!parent.defined {
            $!driver.release-savepoint($!name);
        } else {
            $!driver.commit;
        }
        self!invalidate('committed');
        self!detach;
        self
    }
}

#| Rolls back once; safe to call unconditionally from a LEAVE phaser.
method rollback {
    self!synchronize: {
        return self unless $!state eq 'open';
        CATCH {
            default {
                self!abort($_);
            }
        }
        self!rollback;
        self!invalidate('rolled back');
        self!detach;
        self
    }
}
