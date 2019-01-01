class X::Red is Exception {}

class X::Red::Driver is X::Red {
    has Str $.driver = $*RED-DB.^name;
}

class X::Red::InvalidTableName is X::Red::Driver {
    has Str $.table;

    method message { "'$!table' is an invalid table name for driver { $.driver }" }
}

class X::Red::Driver::Mapped is X::Red::Driver {
    has Exception   $.orig-exception is required;
    has Str         $!orig-message   = $!orig-exception.message;
    has Backtrace   $!orig-backtrace = $!orig-exception.backtrace;

    method msg { !!! }

    method message {
        "{self.msg}\nOriginal error:\n{$!orig-message}"
    }

    method throw is hidden-from-backtrace {
        nextwith $!orig-backtrace
    }
}

class X::Red::Driver::Mapped::UnknownError is X::Red::Driver::Mapped {
    has Str @.fields;
    method msg {
        qq:to/END/
            Unknown Error!!!
            Please, copy this backtrace and open an issue on https://github.com/FCO/Red/issues/new
            Driver: { $.driver }
            Original error: { $.orig-exception.perl }
        END
    }
}

class X::Red::Driver::Mapped::Unique is X::Red::Driver::Mapped {
    has Str @.fields;
    method msg { "Unique constraint ({@!fields.join: ", "}) violated" }
}
