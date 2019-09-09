use Red::Driver;

proto database(|c) is export { * }

#| Receives a driver name and parameters to creates it
multi sub database(Str $type, |c --> Red::Driver) is export {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: |c;
}

#| Receives a driver name and a dbh and creates a driver
multi sub database(Str $type, $dbh --> Red::Driver) {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: :$dbh;
}
