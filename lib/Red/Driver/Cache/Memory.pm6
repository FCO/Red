use Red::AST;
use Red::Driver::CacheWithStrKey;
use Red::Driver::CacheInvalidateOnWrite;

unit class Red::Driver::Cache::Memory does Red::Driver::CacheWithStrKey does Red::Driver::CacheInvalidateOnWrite;

has %!cache;
has %!cache-to-table;
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

multi method get-from-cache(Str $key, :$ast)  {
    note "get-from-cache: $key" if $*RED-CACHE-DEBUG;
    %!cache{$key}
}

multi method set-on-cache(Str:D $key, @data, :$ast) {
    note "set-on-cache: $key" if $*RED-CACHE-DEBUG;
    %!cache{$key} = @data;
    for $ast.tables -> $table {
        note "save on $table.^table(): $key" if $*RED-CACHE-DEBUG;
        %!cache-to-table.push: $table.^table, $key
    }

    my $time = self!time + $!ttl;
    %!expires.push: $time => $key;
    @!times.push: $time;
}

multi method invalidate(Str :$table, *% where ! .elems) {
    with %!cache-to-table{ $table }:delete {
        for .<> // [] -> $key {
            note "invalidate $table: $key" if $*RED-CACHE-DEBUG;
            %!cache{ $key }:delete
        }
    }
}
#multi method invalidate(Str :$table, *%columns) { say "invalidate $table, { %columns.kv.map: { $^a => $^b.value } }" }
