use v6.d;
use Red::Database;
use Red::Driver;
use Red::AST;
use Red::AST::Select;
use Red::AST::Infix;
use Red::AST::Value;
use Red::AST::LastInsertedRow;
use Red::Statement;

unit role Red::Driver::Cache does Red::Driver;

proto cache($, $) is export { * }

multi cache(Str $cache, Str $driver) {
    cache $cache => \(), $driver => \()
}

multi cache(Pair $cache-pair, Str $driver) {
    cache $cache-pair, $driver => \()
}

multi cache(Str $cache, Pair $driver-pair) {
    cache $cache => \(), $driver-pair
}

multi cache(
    Pair (Str :key($cache-driver), Capture :value($cache-conf)),
    Pair (Str :key($driver),       Capture :value($driver-conf))
) is export {
    my $cache = "Red::Driver::Cache::$cache-driver";
    require ::($cache);
    ::($cache).new: :driver(database $driver, |$driver-conf), |$cache-conf
}

multi method get-from-cache(Red::AST)  { ... }
multi method set-on-cache(Red::AST, @) { ... }

has Red::Driver  $.driver is required;

multi method default-type-for(Red::Column $a --> Str:D) { $!driver.default-type-for($a)      }
multi method is-valid-table-name(|c)                    { $!driver.is-valid-table-name(|c)   }
multi method type-by-name(|c)                           { $!driver.type-by-name(|c)          }
multi method inflate(|c)                                { $!driver.inflate(|c)               }
multi method deflate(|c)                                { $!driver.deflate(|c)               }
multi method prepare(Str $_)                            { $!driver.prepare($_)               }
multi method translate(Red::AST $ast, $context?)        { $!driver.translate($ast, $context) }

my class CachedStatement does Red::Statement {
    has Red::AST            $.ast       is required;
    has Iterator            $.iterator  is required;

    method stt-exec($stt, *@bind) { }
    method stt-row($stt) { $!iterator.pull-one }
}

my class Statement does Red::Statement {
    has Red::AST            $.ast       is required;
    has Red::Statement      $.stt       is required;
    has Iterator            $.iterator;

    method stt-exec($stt, *@bind) {
        my @data;
        $!stt.stt-exec: $!stt, |@bind;
        while my $row = $!stt.row {
            @data.push: $row
        }
        note "setting data on cache" if $*RED-CACHE-DEBUG;
        $!driver.set-on-cache: $!ast, @data;
        $!iterator = @data.iterator
    }
    method stt-row($stt) { $!iterator.pull-one }
}

multi method prepare(Red::AST::Select $ast ) {
    CATCH {
        default {
            return $!driver.prepare: $ast
        }
    }
    with self.get-from-cache: $ast {
        PRE .^can: "iterator";
        note "getting data from cache" if $*RED-CACHE-DEBUG;
        return CachedStatement.new: :driver(self), :iterator(.iterator), :$ast
    }
    do for $!driver.prepare: $ast -> $stt {
        Statement.new: :driver(self), :$stt, :$ast
    }
}

