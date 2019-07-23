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
has      $.references = {};

multi method new($name, $type, $nullable, $pk, $unique, $references) {
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

method diff(::?CLASS $b) {
    my @diffs;
    @diffs.push: ( :name{       "-" => self.name,       "+" => $b.name       } ) if self.name       ne $b.name      ;
    @diffs.push: ( :type{       "-" => self.type,       "+" => $b.type       } ) if self.type       ne $b.type      ;
    @diffs.push: ( :nullable{   "-" => self.nullable,   "+" => $b.nullable   } ) if self.nullable   != $b.nullable  ;
    @diffs.push: ( :pk{         "-" => self.pk,         "+" => $b.pk         } ) if self.pk         != $b.pk        ;
    @diffs.push: ( :unique{     "-" => self.unique,     "+" => $b.unique     } ) if self.unique     != $b.unique    ;
    @diffs.push: ( :references{ "-" => self.references, "+" => $b.references } )
        if quietly ?self.references<table> and ?$b.references<table>
            and self.references<table>  ne $b.references<table>
            or  self.references<column> ne $b.references<column>
    ;
    @diffs
}
