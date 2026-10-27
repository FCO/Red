use Red::QueryPlan::Cache;
use JSON::Fast;

subset PositiveInt of Int where * > 0;

# Isolate cache bookkeeping with a hot working set or constant eviction.
sub MAIN(PositiveInt :$iterations = 5000, PositiveInt :$rounds = 7) {
    my @samples;
    my $sink;
    for 1, 16, 128 -> $capacity {
        for False, True -> $churn {
            my $cache = Red::QueryPlan::Cache.new(:$capacity);
            my @keys = (^(($churn ?? 2 !! 1) * $capacity)).map({ "key$_" });
            my $loops = ($iterations / @keys.elems).ceiling.Int;
            my $builds = 0;
            my &build = -> { $builds++; 42 };
            my &task = -> { $sink = $cache.fetch($_, &build) for @keys };
            task() for ^$loops;
            my $warm-builds = $builds;
            for ^$rounds -> $round {
                my $start = now;
                task() for ^$loops;
                @samples.push: %(:$capacity, :$churn, :$round,
                    :microseconds((now - $start).Num * 1e6 / ($loops * @keys.elems)));
            }
            my $expected = $warm-builds + ($churn ?? $rounds * $loops * @keys.elems !! 0);
            die 'Unexpected cache reuse' unless $builds == $expected && $sink.value == 42;
        }
    }
    say to-json(%(:rakudo($*RAKU.compiler.version.Str), :$iterations, :$rounds,
        :samples(@samples)), :pretty);
}
