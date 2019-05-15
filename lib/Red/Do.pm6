use Red::Database;
use Red::Driver;
use X::Red::Exceptions;
unit module Red::Do;

multi red-defaults-from-config() is export {
    if "./.red.json".IO.f {
        return red-defaults-from-config "./.red.json"
    }
    X::Red::Defaults::FromConfNotFound.new(:file<./.red.json>).throw
}

multi red-defaults-from-config($file where .IO.f) is export {
    require ::("Config");
    my $conf = ::("Config").new;
    my $defaults = $conf.read($file.IO.absolute).get;
    my %defaults = $defaults.kv.map: -> $name, %data {
        $name => [%data<red-driver>, :default(so %data<default>), |($_ with %data<positional>), |(.pairs with %data<named>)]
    }
    red-defaults |%defaults
}

multi red-defaults(Str $driver, |c) is export {
    %GLOBAL::RED-DEFULT-DRIVERS = default => database $driver, |c
}

multi red-defaults(*%drivers) is export {
    my Bool $has-default = False;
    %GLOBAL::RED-DEFULT-DRIVERS = %drivers.kv.map(-> $name, ($driver, Bool :$default, |c) {
        if $default {
            X::Red::Do::DriverDefinedMoreThanOnce.new.throw if $has-default;
            $has-default = True;
        }

        my \db = do if $driver ~~ Red::Driver {
            $driver
        } else {
            database $driver, |[|c];
        }

        |%(
            $name     => db,
            |(default => db if $default)
        )
    }).Hash;
}

multi red-do(&block, :$use = "default") is export {
    X::Red::Do::DriverNotDefined.new(:driver($use)).throw unless %GLOBAL::RED-DEFULT-DRIVERS{$use}:exists;
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$use};
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
