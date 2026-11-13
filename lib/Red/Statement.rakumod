#| Base role to DB statements
#| Returned by .query
unit role Red::Statement;
has $.statement;
has @.binds is rw;
has $.driver is required;
has Bool $!predefined-bind = False;
has Mu $.transaction-guard;
has Bool $!executed = False;

#| Attaches the lifetime of the transaction which prepared this statement.
method guarded-by(Mu:D $guard) {
    my $statement = self.clone(:transaction-guard($guard));
    $guard.register-statement($statement);
    $statement
}

# Release resources through the driver before closing a transaction scope.
method finish-transaction { $!driver.finish-statement($!statement, :executed($!executed)) }

# How to execute a query must be implemented
method stt-exec($, *@) { ... }

method predefined-bind { $!predefined-bind = True }

#| Execute the pre-prepared query
method execute(*@binds) is hidden-from-backtrace {
    my &execute = {
        CATCH {
            default {
                $!driver.map-exception($_).throw
            }
        }
        $!statement = self.stt-exec: $!statement, |@binds;
        $!executed = True;
        self
    };
    $!transaction-guard.defined ?? $!transaction-guard.protect(&execute) !! execute()
}

method prepare($query) {
    $!transaction-guard.defined
        ?? $!transaction-guard.scoped-driver.prepare($query)
        !! $!driver.prepare($query)
}

#| How to get a row must be implemented
method stt-row($ --> Hash()) { ... }

#| Get the next row
method row {
    my &row = {
        my \resp = self.stt-row: $!statement;
        note resp if $*RED-DEBUG-RESPONSE;
        resp
    };
    $!transaction-guard.defined ?? $!transaction-guard.protect(&row) !! row()
}
