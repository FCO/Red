use Red::Column;

class X::Red is Exception {}

class X::Red::NoOperatorsDefined is X::Red {
    has Str $.meth is required where <first grep map>.any;
    method message {
        qq:to/END/
        Red operators not defined while calling $!meth. It's probably not doing what you mean.
        Please use Red (or Red::Operators) before using $!meth on a Red::ResultSet.
        If that's what you want, please set \$*RED-DONT-FAIL-WITHOUT-OPERATORS to True.
        END
    }
}

class X::Red::RedDbNotDefined is X::Red {
    method message { Q[$*RED-DB wasn't defined] }
}

class X::Red::Defaults::FromConfNotFound is X::Red {
    has Str $.file = "./.red.json";
    method message { "Red configuration file ($!file) not found" }
}

class X::Red::Do is X::Red {
    has Str $.driver = "default"
}

class X::Red::Do::DriverNotDefined is X::Red::Do {
    method message { "Driver $.driver not specified" }
}

class X::Red::Do::DriverDefinedMoreThanOnce is X::Red::Do {
    method message { "Driver $.driver defined mor than once" }
}

class X::Red::Driver is X::Red {
    has Str $.driver = $*RED-DB.^name;
}

class X::Red::RelationshipNotColumn is X::Red {
    has Attribute   $.relationship;
    has             $.points-to;

    method message {
        "The relationship '$!relationship.name()' points to a {$!points-to.^name} ($!points-to.Str()). Should point to a column that is refering to another column."
    }
}

class X::Red::RelationshipNotRelated is X::Red {
    has Attribute   $.relationship;
    has Red::Column $.points-to;

    method message {
        "The relationship '$!relationship.name()' points to a column ('$!points-to.attr-name()') that does not refer to any where"
    }
}

class X::Red::InvalidTableName is X::Red::Driver {
    has Str $.table;

    method message { "'$!table' is an invalid table name for driver { $.driver }" }
}

class X::Red::UpdateNoId is X::Red::Driver {
    method message { "Update on a model without id isn't allowed" }
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

class X::Red::Driver::Mapped::TableExists is X::Red::Driver::Mapped {
    has Str $.table is required;
    method msg { "Table $!table already exists" }
}
