use Red;

my @exp;
sub EXPORT(*@experimentals--> Map()) {
    |Red.exports(@experimentals)
}

proto red-config(| --> Map()) is export {*}

multi red-config(:@schema, |c --> Map()) {
    red-config :schema(schema @schema), |c
}

multi red-config(
    Red::Schema :$schema,
    Str         :$schema-name   = "Schema",
    Red::Driver :$database,
    Bool        :$export-schema = True,
    Bool        :$export-models = True,
    Bool        :$debug,
    +@experimentals,
    --> Map()
) {
    |Red.exports(@experimentals),
    |('$*RED-DB'    => $_ with $database),
    |('$*RED-DEBUG' => $_ with $debug),
    |($schema-name  => $schema if $export-schema),
    |(|$schema.models if $schema && $export-models),
}
