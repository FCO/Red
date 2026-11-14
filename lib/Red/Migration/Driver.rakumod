use X::Red::Migration;

unit module Red::Migration::Driver;

# Capture the type in the scope of require and retain it before another driver
# load can replace the lexical Red::Driver stash on legacy Rakudo. Share this
# resolver between preparation and SQL parsing, including external drivers.
sub migration-driver(Str $name) is export {
    X::Red::Migration.new(:reason("Invalid migration driver: $name")).throw
        unless $name ~~ /^ <[A..Za..z_]> <[A..Za..z_0..9]>* $/;
    state %drivers;
    return %drivers{$name} if %drivers{$name}:exists;
    my $driver-name = "Red::Driver::$name";
    require ::($driver-name);
    %drivers{$name} = ::($driver-name)
}
