#| Base role to DB statements
#| Returned by .query
unit role Red::Statement;
has $.statement;
has @.binds is rw;
has $.driver is required;
has Bool $!predefined-bind = False;

# How to execute a query must be implemented
method stt-exec($, *@) { ... }

method predefined-bind { $!predefined-bind = True }

#| Execute the pre-prepared query
method execute(*@binds) is hidden-from-backtrace {
    CATCH {
        default {
            $!driver.map-exception($_).throw
        }
    }
    $!statement = self.stt-exec: $!statement, |@binds;
    self
}

method prepare($query) { $!driver.prepare: $query }

#| How to get a row must be implemented
method stt-row($ --> Hash()) { ... }

#| Get the next row
method row {
    my \resp = self.stt-row: $!statement;
    note resp if $*RED-DEBUG-RESPONSE;
    resp
}
