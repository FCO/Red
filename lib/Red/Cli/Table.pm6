use Red::Utils;
use Red::Cli::Column;
unit class Red::Cli::Table;

has Str $.name is required;
has @.columns;

method !use-red           { "use Red;" }
method !model-definition  { "unit model { kebab-to-camel-case($!name) };" }

method to-code {
    qq:to/END/;
    { self!use-red }

    { self!model-definition }

    { do for @!columns -> $col {
        $col.to-code
    }.join: "\n" }
    END
}
