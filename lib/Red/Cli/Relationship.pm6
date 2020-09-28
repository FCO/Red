use Red::Utils;
use Red::Cli::Column;
unit class Red::Cli::Relationship;

has Red::Cli::Column $.id is required;
has &.transform-name = -> $name { S/_id$// given $name }

method to-code(:$schema-class) {
    qq:to/END/.chomp;
    has \$.{ snake-to-kebab-case &!transform-name( $!id.name ) } is relationship({[
            "\n\{ .{ $!id.formated-name } \}",
            "\n:model<{ snake-to-camel-case $!id.references<table> }>",
            ("\n:require<$schema-class>" if $schema-class),
        ].join(",").indent: 4}
    );
    END
}
