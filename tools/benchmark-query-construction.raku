use Red;
use Red::Compiler::RakuAST;
use JSON::Fast;

CHECK red-compile if (%*ENV<RAKUDO_RAKUAST> // '0') eq '1';

model QueryConstructionBenchmarkRow {
    has Int $.id is serial;
    has Int $.number is column;
}

subset PositiveInt of Int where * > 0;

# Time construction only; validate the queries before warming the measured tasks.
sub MAIN(PositiveInt :$iterations = 200, PositiveInt :$rounds = 7) {
    my $*RED-DB = database 'SQLite';
    my $*RED-FALLBACK = False;
    QueryConstructionBenchmarkRow.^create-table;
    QueryConstructionBenchmarkRow.^create(:number($_)) for 1..3;
    my $minimum = 1;
    my $offset = 7;
    my $projected-minimum = 8;
    my %tasks =
        filter => -> { QueryConstructionBenchmarkRow.^all.grep({ .number > $minimum }) },
        projection => -> { QueryConstructionBenchmarkRow.^all.map({ .number * 2 + $offset }) },
        chain => -> {
            QueryConstructionBenchmarkRow.^all.map({ .number + $offset })
                .grep({ $_ > $projected-minimum }).map({ $_ * 2 })
        };
    my %expected = filter => [2, 3], projection => [9, 11, 13], chain => [18, 20];
    for <filter projection chain> -> $scenario {
        my $query = %tasks{$scenario}();
        my @values = $scenario eq 'filter'
            ?? $query.List.map(*.number).sort.Array !! $query.List.sort.Array;
        die "Incorrect $scenario results" unless @values eqv %expected{$scenario};
    }
    my $sink;
    for %tasks.values -> &task { $sink = task() for ^100 }
    my @samples;
    for ^$rounds -> $round {
        for ($round %% 2 ?? <filter projection chain> !! <chain projection filter>) -> $scenario {
            my &task = %tasks{$scenario};
            my $start = now;
            $sink = task() for ^$iterations;
            @samples.push: %(:$scenario, :$round,
                :microseconds((now - $start).Num * 1e6 / $iterations));
        }
    }
    say to-json(%(:rakudo($*RAKU.compiler.version.Str), :$iterations, :$rounds,
        :rakuast((%*ENV<RAKUDO_RAKUAST> // '0') eq '1'), :samples(@samples)), :pretty);
}
