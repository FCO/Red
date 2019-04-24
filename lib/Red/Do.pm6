use Red::Database;
unit module Red::Do;

multi red-defaults(Str $driver, |c) is export {
    %GLOBAL::RED-DEFULT-DRIVERS = default => database $driver, |c
}

multi red-defaults(*%drivers) is export {
    my Bool $has-default = False;
    %GLOBAL::RED-DEFULT-DRIVERS = %drivers.kv.map(-> $name, ($driver, Bool :$default, |c) {
        if $default {
            die "More than one default driver" if $has-default;
            $has-default = True;
        }
        my \db = database $driver, |c;
        |%(
            $name     => db,
            |(default => db if $default)
        )
    }).Hash;
}

multi red-do(&block, :$use = "default") is export {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$use};
    die "Driver $use not specified" unless %GLOBAL::RED-DEFULT-DRIVERS{$use}:exists;
    # TODO: test if its connected and reconnect if it's not
    block $*RED-DB
}

multi red-do(*@blocks) is export {
    for @blocks {
        when Pair {
            red-do :use(.key), .value
        }
        default {
            .&red-do
        }
    }
}
