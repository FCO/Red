use X::Red::Exceptions;
use Red::Runtime::Configuration;

=head2 Red::DB

#| Returns the database connection
sub get-RED-DB is export {
    my $driver = $*RED-DB;
    return $driver if $driver.defined;
    if %*RED-DEFAULT-DRIVERS.defined and %*RED-DEFAULT-DRIVERS<default>:exists {
        return %*RED-DEFAULT-DRIVERS<default>
    }
    $driver = runtime-database();
    return $driver if $driver.defined;
    X::Red::RedDbNotDefined.new.throw
}
