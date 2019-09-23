use Red::Database;
use Red::Driver;
use X::Red::Exceptions;
use Red::Class;
use Red::Event;
use Red::DB;

=head1 This module is experimental, to use it, do:

=head2 Red::Do

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
    %GLOBAL::RED-DEFULT-DRIVERS = %drivers.kv.map(-> $name, $_ {
        when Capture|Positional {
            my (Str $driver, Bool $default);
            my \c = \();
            :($driver, Bool :$default, |c) := $_;
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
        }
        when Red::Driver:D {
            $name => $_
        }
    }).Hash;
}

sub red-emit(Str() $name, $data) is export {
    get-RED-DB.emit: Red::Event.new: :$name, :$data
}

sub red-tap(Str() $name, &func, :$red-db = $*RED-DB) is export {
    Red::Class.instance.events.grep({ .name eq $name }).tap: -> Red::Event $_ {
        my $*RED-DB = $red-db;
        func .data
    }
}

sub run-red-do($*RED-DB, &block) {
    # TODO: test if its connected and reconnect if it's not
    block $*RED-DB
}

proto red-do(|) {
    my %red-supplies := %*RED-SUPPLIES // {};
    {
        my %*RED-SUPPLIES := %red-supplies;
        {*}
    }
}

#| Receives a block and optionally a connection name.
#| Runs the block with the connection with that name
multi red-do(*@blocks where .all ~~ Callable, Str :$with = "default", :$async) is export {
    X::Red::Do::DriverNotDefined.new(:driver($with)).throw unless %GLOBAL::RED-DEFULT-DRIVERS{$with}:exists;
    my @ret = do for @blocks {
        red-do :with(%GLOBAL::RED-DEFULT-DRIVERS{$with}), $_, :$async
    }
    if $async {
        return start await @ret
    }
    return @ret.head if @ret == 1;
    @ret
}


#| Receives a block and optionally a connection name.
#| Runs the block with the connection with that name
#| synchronously
multi red-do(&block, Red::Driver:D :$with, :$async where not *) is export {
    run-red-do $with, &block
}

#| Receives a block and optionally a connection name.
#| Runs the block with the connection with that name
#| asynchronously
multi red-do(&block, Red::Driver:D :$with = "default", :$async! where so *) is export {
    start run-red-do $with, &block
}

#| Receives list of pairs with connection name and block
#| or blocks (assuming the default connection) or named
#| args where the name is the name of the connection
#| Runs each block with the connection with that name
multi red-do(*@blocks, Bool :$async, *%pars where *.none.key eq "with") is export {
    my @ret = do for |@blocks , |%pars.pairs -> $block {
        when $block ~~ Pair {
            given $block.key -> $with {
                when $with ~~ Positional {
                    red-do :$async, |$with.map: { Pair.new: $_, $block.value }
                }
                default {
                    red-do :$async, :$with, $block.value
                }
            }
        }
        when $block ~~ Callable {
            red-do :$async, $block
        }
    }
    return start await @ret if $async;
    @ret
}