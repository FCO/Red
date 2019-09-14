use X::Red::Exceptions;

#| Returns the database connection
sub get-RED-DB is export {
    with $*RED-DB {
        .return
    }
    if %*RED-DEFULT-DRIVERS.defined and %*RED-DEFULT-DRIVERS<default>:exists {
        return %*RED-DEFULT-DRIVERS<default>
    }
    X::Red::RedDbNotDefined.new.throw
}
