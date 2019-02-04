use Red::Driver;

proto database(|c) is export { * }

multi sub database(Str $type, |c) is export {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: |c;
}

multi sub database(Str $type, $dbh) {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: :$dbh;
}
