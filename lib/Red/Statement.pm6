unit role Red::Statement;
has $.statement;
has @.binds;
has $.driver is required;

method stt-exec($, *@) { ... }

method execute(*@binds) {
    $!statement = do if self.?predefined-bind {
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
