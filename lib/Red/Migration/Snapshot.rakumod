use Red::Cli::Table;
use Red::Cli::Column;

# Snapshots contain constructor expressions, never live model implementations.
unit class Red::Migration::Snapshot;

has Red::Cli::Table @.tables;

method !literal($value --> Str) {
    given $value {
        when Associative {
            '$(%(' ~ .keys.sort.map({ .raku ~ ' => ' ~ self!literal($value{$_}) }).join(', ') ~ '))'
        }
        when Positional { '[' ~ .list.map({ self!literal($_) }).join(', ') ~ ']' }
        default { .raku }
    }
}

method source(--> Str) {
    my @tables = @!tables.sort(*.name).map: -> $table {
        my @columns = $table.columns.map: -> $column {
            my @args = <name type raku-type nullable pk unique>.map: -> $field {
                "$field => " ~ $column."$field"().raku
            };
            @args.push: 'references => ' ~ self!literal($column.references.Hash);
            @args.push: 'auto-increment => ' ~ $column.auto-increment.raku
                if $column.^can('auto-increment');
            'Red::Cli::Column.new(' ~ @args.join(', ') ~ ')'
        };
        my @args = 'name => ' ~ $table.name.raku,
            'model-name => ' ~ $table.model-name.raku,
            'columns => [' ~ @columns.join(",\n        ") ~ ']';
        @args.push: 'constraints => ' ~ self!literal($table.constraints.sort(*.join('|')).Array)
            if $table.^can('constraints');
        @args.push: 'indexes => ' ~ self!literal($table.indexes.sort(*.<name>).Array);
        @args.push: 'checks => ' ~ self!literal($table.checks.sort.Array);
        'Red::Cli::Table.new(' ~ @args.join(",\n    ") ~ ')'
    };
    "use Red::Cli::Table;\nuse Red::Cli::Column;\n[\n"
        ~ @tables.join(",\n") ~ "\n]\n"
}

method load(::?CLASS:U: IO() $path --> ::?CLASS) {
    use MONKEY-SEE-NO-EVAL;
    my $tables = EVALFILE $path.Str;
    self.new(:tables($tables.list))
}
