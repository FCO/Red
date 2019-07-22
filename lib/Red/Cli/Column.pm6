use Red::Utils;
use Red::DB;
unit class Red::Cli::Column;

has      $.table      is rw;
has Str  $.name       is required;
has Str  $.formated-name = snake-to-kebab-case $!name;
has Str  $.type       is required;
has Str  $.perl-type  = get-RED-DB.type-for-sql: $!type;
has Bool $.nullable   = True;
has Bool $.pk         = False;
has Bool $.unique     = False;
has      $.references;

method new($name, $type, $nullable, $pk, $unique, $references) {
    self.bless: :$name, :$type, :nullble(?$nullable), :pk(?$pk), :unique(?$unique), :$references
}

method !modifier(Str :$schema-class) {
    do given self {
        when ?.pk         { "id" }
        when ?.references {
            qq:to/END/.chomp;
            referencing\{{
                    [
                        "\n:model<{
                            snake-to-camel-case self.references<table>
                        }>",
                        "\n:column<{
                            snake-to-kebab-case self.references<column>
                        }>",
                        ("\n:require<{ $schema-class }>" with $schema-class)
                    ].join(",").indent: 4
                }
            }
            END
        }
        default          { "column" }
    }
}

method to-code(Str :$schema-class) {
    "has {$!perl-type} \$.{ $!formated-name } is {
        self!modifier(
            |(:$schema-class with $schema-class)
        ).chomp
    };"
}
