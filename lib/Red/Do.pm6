use Red::Database;
use Red::Driver;
use X::Red::Exceptions;

=head1 This module is experimental, to use it, do:
=begin code :lang<perl6>
use Red <red-do>;
=end code

unit module Red::Do;

#| Loads Red configuration (mostly the database connection)
#| from a json configuration json file. If the file isn't defined
#| try to get it on `./.red.json`
multi red-defaults-from-config() is export {
    if "./.red.json".IO.f {
        return red-defaults-from-config "./.red.json"
    }
    X::Red::Defaults::FromConfNotFound.new(:file<./.red.json>).throw
}

#| Loads Red configuration (mostly the database connection)
#| from a json configuration json file. If the file isn't defined
#| try to get it on `./.red.json`
multi red-defaults-from-config($file where .IO.f) is export {
    require ::("Config");
    my $conf = ::("Config").new;
    my $defaults = $conf.read($file.IO.absolute).get;
    my %defaults = $defaults.kv.map: -> $name, %data {
        $name => [%data<red-driver>, :default(so %data<default>), |($_ with %data<positional>), |(.pairs with %data<named>)]
    }
    red-defaults |%defaults
}

#| Sets the default connection to be used
multi red-defaults(Str $driver, |c) is export {
    %GLOBAL::RED-DEFULT-DRIVERS = default => database $driver, |c
}

#| Sets the default connections to be used.
#| The key is the name of the connection and the value the connection itself
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

#| Receives a block and optionally a connection name.
#| Runs the block with the connection with that name
multi red-do(&block, :$use = "default") is export {
    X::Red::Do::DriverNotDefined.new(:driver($use)).throw unless %GLOBAL::RED-DEFULT-DRIVERS{$use}:exists;
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$use};
    # TODO: test if its connected and reconnect if it's not
    block $*RED-DB
}

#| Receives list of pairs with connection name and block
#| Runs each block with the connection with that name
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
