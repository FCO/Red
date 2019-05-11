use Red::AST;
use Red::Driver::CacheWithStrKey;

unit class Red::Driver::Cache::Memory does Red::Driver::CacheWithStrKey;

has %!cache;
has %!expires;
has @!times;
has Int $.ttl = 10;

submethod TWEAK(|) {
    start react whenever Supply.interval: 1 {
        CATCH {
            default {
                .say
            }
        }
        my $time = self!time;
        while (@!times.head // Inf) <= $time { #>
            my $t = @!times.shift;
            for |(%!expires{$t}:delete) -> $key {
                next without $key;
                note "remove: $key" if $*RED-CACHE-DEBUG;
                %!cache{$key}:delete
            }
        }
    }
}

method !time { now.Int }

multi method get-from-cache(Str $key)  {
    note "get-from-cache: $key" if $*RED-CACHE-DEBUG;
    %!cache{$key}
}

multi method set-on-cache(Str $key, @data) {
    note "set-on-cache: $key" if $*RED-CACHE-DEBUG;
    %!cache{$key} = @data;

    my $time = self!time + $!ttl;
    %!expires.push: $time => $key;
    @!times.push: $time;
}
