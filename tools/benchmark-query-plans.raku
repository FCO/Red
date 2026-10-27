use Red;
use Red::Compiler::Template;
use Red::Compiler::Emitter;
use Red::QueryPlan::Cache;
use JSON::Fast;

model QueryPlanBenchmarkRow {
    has Int $.id is serial;
    has Int $.number is column;
}

sub MAIN(Int :$iterations = 200, Int :$rounds = 5) {
    my $*RED-DB = database 'SQLite';
    my $*RED-FALLBACK = False;
    QueryPlanBenchmarkRow.^create-table;
    QueryPlanBenchmarkRow.^create(:number($_)) for ^10;
    my $minimum = 3;
    my @plan = ['op', 'Gt', ['field', ['subject'], 'number'], ['capture', 0]];
    my $template = Red::Compiler::Template.new(:@plan, :getters([-> { $minimum }]),
        :builder(Red::Compiler::Emitter.build(@plan)),
        :validator(Red::Compiler::Emitter.validator(@plan)));
    sub query() {
        QueryPlanBenchmarkRow.^all.grep({ .number > $minimum }, :red-ast($template))
    }
    my @samples;
    my @prototype-samples;
    my $sink;
    for ^$rounds -> $round {
        for ($round %% 2 ?? (False, True) !! (True, False)) -> $enabled {
            my $*RED-QUERY-PLAN-CACHE = $enabled;
            temp $template = $template.clone(
                :filter-cache(Red::QueryPlan::Cache.new),
                :sql-cache(Red::QueryPlan::Cache.new));
            my $cold-start = now;
            my $query = query();
            $sink = $query.List.eager;
            @samples.push: %(:stage<cold-query>, :$enabled, :$round,
                :microseconds((now - $cold-start).Num * 1e6));
            $query.List.eager for ^5;
            for <construction translation execution> -> $stage {
                my &task = do given $stage {
                    when 'construction' { -> { $sink = query() } }
                    when 'translation' {
                        -> {
                            my $*RED-DRY-RUN = True;
                            $sink = $query.iterator
                        }
                    }
                    when 'execution' { -> { $sink = $query.List.eager } }
                };
                my $start = now;
                task() for ^$iterations;
                @samples.push: %(:$stage, :$enabled, :$round,
                    :microseconds((now - $start).Num * 1e6 / $iterations));
            }
        }
    }
    # Isolate the first model specialization, with an empty predicate cache.
    # Both variants retain the same compiler factory and private capture binding.
    for ^$rounds -> $round {
        for ($round %% 2 ?? (False, True) !! (True, False)) -> $prototype-enabled {
            my $*RED-QUERY-PLAN-CACHE = True;
            my $source = $template.clone(:filter-prototype(
                $prototype-enabled ?? $template.filter-prototype !! Red::AST));
            my $start = now;
            for ^$iterations {
                my $fresh = $source.clone(:filter-cache(Red::QueryPlan::Cache.new));
                $sink = $fresh.bind(QueryPlanBenchmarkRow).cached-filter(QueryPlanBenchmarkRow);
            }
            @prototype-samples.push: %(:$round, :$prototype-enabled,
                :microseconds((now - $start).Num * 1e6 / $iterations));
        }
    }
    say to-json(%(:rakudo($*RAKU.compiler.version.Str), :$iterations, :$rounds,
        :samples(@samples), :prototype-samples(@prototype-samples)), :pretty);
}
