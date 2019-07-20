use Red::Utils;
unit class Red::Cli::Column;

has Str  $.name       is required;
has Str  $.type       is required;
has Bool $.nullable   = True;
has Bool $.pk         = False;
has Bool $.unique     = False;
has      $.references;

method new($name, $type, $nullable, $pk, $unique, $references) {
    self.bless: :$name, :$type, :nullble(?$nullable), :pk(?$pk), :unique(?$unique), :$references
}

method !modifier {
    do given self {
        when ?.pk         { "id" }
        when ?.references {
            qq:to/END/
            referencing\{
                :model<{
                    snake-to-camel-case self.references<table>
                }>,
                :column<{
                    snake-to-kebab-case self.references<column>
                }>,
                :require<Schema>
            }
            END
        }
        default          { "column" }
    }
}

method to-code {
    "has \$.{ snake-to-kebab-case($!name) } is { self!modifier.chomp };"
}
