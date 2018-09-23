unit role Red::Statement;
has $.statement;
has @.binds is rw;
has $.driver is required;
has Bool $!predefined-bind = False;

method stt-exec($, *@) { ... }

method predefined-bind { $!predefined-bind = True }

method execute(*@binds) {
    $!statement = do if $!predefined-bind {
        self.stt-exec: $!statement, |@binds
    } else {
        self.stt-exec: $!statement, |@!binds
    }
    self
}

method prepare($query) { $!driver.prepare: $query }

method stt-row($ --> Hash()) { ... }

method row {
    self.stt-row: $!statement
}
