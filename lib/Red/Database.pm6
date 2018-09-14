use Red::Driver;

sub database(Str $type, |c) is export {
    my $driver-name = "Red::Driver::$type";
    require ::($driver-name);
    my Red::Driver $driver = ::($driver-name).new: |c;
}
