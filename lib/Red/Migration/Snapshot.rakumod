use Red::Cli::Table;
use Red::Cli::Column;
use Red::Migration::Artifact;

# Snapshots contain constructor expressions, never live model implementations.
=head2 Red::Migration::Snapshot

unit class Red::Migration::Snapshot;

has Red::Cli::Table @.tables;

#| Serialize the schema deterministically as typed config, table and column builders. Preserve
#| historical Raku types, SQL mappings, key information and portable descriptors without importing
#| application models.
method source(--> Str) {
    my @tables = @!tables.sort(*.name).map: -> $table {
        my @columns = $table.columns.map: -> $column {
            my @args = <name type raku-type nullable pk unique>.map: -> $field {
                ".$field = " ~ $column."$field"().raku ~ ';'
            };
            @args.push: '.type-origin = ' ~ $column.type-origin.raku ~ ';';
            @args.push: '.type-overrides = ' ~ literal($column.type-overrides, 4) ~ ';';
            @args.push: '.references = ' ~ literal($column.references.Hash, 4) ~ ';';
            @args.push: '.auto-increment = ' ~ $column.auto-increment.raku ~ ';'
                if $column.^can('auto-increment');
            "            column(\{\n                " ~ @args.join("\n                ")
                ~ "\n            })"
        };
        my @args = '.name = ' ~ $table.name.raku ~ ';',
            '.model-name = ' ~ $table.model-name.raku ~ ';',
            ".columns = [\n" ~ @columns.join(",\n") ~ "\n        ];";
        @args.push: '.constraints = ' ~ literal($table.constraints.sort(*.join('|')).Array, 2) ~ ';'
            if $table.^can('constraints');
        @args.push: '.indexes = ' ~ literal($table.indexes.sort(*.<name>).Array, 2) ~ ';';
        @args.push: '.checks = ' ~ literal($table.checks.sort.Array, 2) ~ ';';
        @args.push: '.portable-indexes = ' ~ literal($table.portable-indexes.Array, 2) ~ ';';
        @args.push: '.portable-checks = ' ~ literal($table.portable-checks.Array, 2) ~ ';';
        @args.push: '.primary-key = ' ~ literal($table.primary-key.Array, 2) ~ ';';
        "    table(\{\n        " ~ @args.join("\n        ") ~ "\n    })"
    };
    "use Red::Migration::Artifact 'schema';\n\nconfig \{\n    .tables = [\n"
        ~ @tables.map(*.indent(4)).join(",\n") ~ "\n    ];\n}\n"
}

#| Evaluate a trusted schema artifact and reconstruct a snapshot. Accept both current configuration
#| builders and legacy table collections.
method load(::?CLASS:U: IO() $path --> ::?CLASS) {
    use MONKEY-SEE-NO-EVAL;
    my $tables = EVALFILE $path.Str;
    $tables = $tables.artifact-data if $tables.^can('artifact-data');
    self.new(:tables($tables.list))
}
