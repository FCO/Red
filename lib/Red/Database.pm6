use Red::Driver;
unit module Red::Database;
=head2 Red::Database

proto database(|c) is export { * }

#| Accepts an SQL driver name and parameters and uses them to create
#| an instance of `Red::Driver` class.
#| The driver name is used to specify a particular driver from
#| `Red::Driver::` family of modules, so `SQLite` results in
#| constructing an instance of `Red::Driver::SQLite` class.
#| All subsequent attributes after the driver name will be
#| directly passed to the constructor of the driver.
multi sub database(Str $type, |c --> Red::Driver) is export {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: |c;
    $driver.auto-register;
    $driver
}

#| Accepts an SQL driver name and a database handle, and
#| creates an instance of `Red::Driver` passing it the handle.
multi sub database(Str $type, $dbh --> Red::Driver) {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: :$dbh;
    $driver.auto-register;
    $driver
}
