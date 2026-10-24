use Red;
use JSON::Fast;

model ModelAccessBenchmarkRow {
    has Int $.id is serial;
    has Int $.number is rw is column;
    has Str $.label is column;
}

subset PositiveInt of Int where * > 0;

# Database setup, validation and warmup are excluded from the runtime samples.
sub MAIN(PositiveInt :$rows = 100, PositiveInt :$load-iterations = 30,
    PositiveInt :$access-iterations = 10000, PositiveInt :$rounds = 7) {
    my $*RED-DB = database 'SQLite';
    ModelAccessBenchmarkRow.^create-table;
    ModelAccessBenchmarkRow.^create(:number($_), :label("row$_")) for ^$rows;
    my $query = ModelAccessBenchmarkRow.^all;
    my $row = $query.head;
    my $sink;
    my %tasks =
        load => -> { $sink = $query.List.map({ .number + .number }).sum },
        read => -> { $sink = $row.number + $row.number },
        write => -> { $row.number = 42 };
    %tasks<load>();
    die 'Incorrect loaded values' unless $sink == $rows * ($rows - 1);
    for %tasks.values -> &task { task() for ^30 }
    my @samples;
    for ^$rounds -> $round {
        for ($round %% 2 ?? <load read write> !! <write read load>) -> $stage {
            my $iterations = $stage eq 'load' ?? $load-iterations !! $access-iterations;
            my &task = %tasks{$stage};
            my $start = now;
            task() for ^$iterations;
            @samples.push: %(:$stage, :$round,
                :microseconds((now - $start).Num * 1e6 / $iterations));
        }
    }
    die 'Incorrect write' unless $row.number == 42;
    say to-json(%(:rakudo($*RAKU.compiler.version.Str), :$rows, :$rounds,
        :$load-iterations, :$access-iterations, :samples(@samples)), :pretty);
}
