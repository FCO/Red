use X::Red::Exceptions;

=head2 Red::DB

#| Returns the database connection
sub get-RED-DB is export {
    my $driver = $*RED-DB;
    return $driver if $driver.defined;
    if %*RED-DEFAULT-DRIVERS.defined and %*RED-DEFAULT-DRIVERS<default>:exists {
        return %*RED-DEFAULT-DRIVERS<default>
    }
    X::Red::RedDbNotDefined.new.throw
}
