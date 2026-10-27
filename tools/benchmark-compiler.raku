use Red;
use Red::Compiler::Template;
use Red::Compiler::Emitter;
use Red::Type::Json;
use JSON::Fast;

model CompilerBenchmarkRow {
    has Int $.number is column;
    has Int $.other is column;
    has Str $.label is column;
    has Json $.payload is column;
}

# Factory specialization and warmup are excluded from the runtime samples.
subset PositiveInt of Int where * > 0;

sub MAIN(PositiveInt :$iterations = 1000, PositiveInt :$rounds = 7) {
    my @field = ['field', ['subject'], 'number'];
    my @plans =
        ['field', @field.Array],
        ['arithmetic', ['op', 'Mul', ['op', 'Sum', @field.Array, ['literal', 42]],
            ['op', 'Sum', ['field', ['subject'], 'other'], ['literal', 2]]]],
        ['conditional', ['case', ['op', 'Gt', @field.Array, ['literal', 500]],
            ['op', 'Mul', @field.Array, ['literal', 2]],
            ['op', 'Sum', @field.Array, ['literal', 1]]]],
        ['hash', ['hash', ['value', ['op', 'Sum', @field.Array,
            ['field', ['subject'], 'other']]], ['label', ['field', ['subject'], 'label']]]],
        ['json', ['exists', ['field', ['subject'], 'payload'], ['literal', 'value']]],
        ['capture', ['op', 'Gt', @field.Array, ['capture', 0]]];
    my @samples;
    my $sink;
    for @plans -> ($scenario, $plan) {
        my @plan = $plan.list;
        my @getters = $scenario eq 'capture' ?? (-> { 500 },) !! ();
        my %templates =
            interpreted => Red::Compiler::Template.new(:@plan, :@getters,
                :prevalidate(so @getters)),
            direct => Red::Compiler::Template.new(:@plan, :@getters,
                :prevalidate(so @getters), :builder(Red::Compiler::Emitter.build(@plan)),
                :validator(Red::Compiler::Emitter.validator(@plan)));
        my %tasks;
        for <direct interpreted> -> $variant {
            my $template = %templates{$variant};
            %tasks{$variant} = -> { $sink = $template.bind(CompilerBenchmarkRow)
                .branches(CompilerBenchmarkRow) };
            %tasks{$variant}() for ^100;
        }
        for ^$rounds -> $round {
            for ($round %% 2 ?? <direct interpreted> !! <interpreted direct>) -> $variant {
                my $start = now;
                %tasks{$variant}() for ^$iterations;
                my $microseconds = (now - $start).Num * 1e6 / $iterations;
                @samples.push: %(:$scenario, :$variant, :$round, :$microseconds);
            }
        }
    }
    say to-json(%(:rakudo($*RAKU.compiler.version.Str), :$iterations, :$rounds,
        :samples(@samples)), :pretty);
}
