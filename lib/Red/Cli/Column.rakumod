use Red::Utils;
use Red::DB;
unit class Red::Cli::Column;

has      $.table      is rw;
has Str  $.name       is required;
has Str  $.formated-name = snake-to-kebab-case $!name;
has Str  $.type       is required;
has Str  $.perl-type  = get-RED-DB.type-for-sql: $!type.lc;
has Bool $.nullable   = True;
has Bool $.pk         = False;
has Bool $.unique     = False;
has      $.references = {};

multi method new($name, $type, $nullable, $pk, $unique, $references) {
    self.bless: :$name, :$type, :nullble(?$nullable), :pk(?$pk), :unique(?$unique), :$references
}

multi method gist(::?CLASS:D:) {
    "Red::Cli::Column.new(:name($!name), :type($!type), :nullable($!nullable), :pk($!pk), :unique($!unique), {
        ":references($_)" with $!references
    } #`( table => $!table.name() ))"
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
    if self.name ne $b.name {
        @diffs.push: [ $!name, "+", "name", $b.name   ];
        @diffs.push: [ $!name, "-", "name", self.name ];
    }
    if self.type ne $b.type {
        @diffs.push: [ $!name, "+", "type", $b.type   ];
        @diffs.push: [ $!name, "-", "type", self.type ];
    }
    if self.nullable != $b.nullable {
        @diffs.push: [ $!name, "+", "nullable", $b.nullable   ];
        @diffs.push: [ $!name, "-", "nullable", self.nullable ];
    }
    if self.pk != $b.pk {
        @diffs.push: [ $!name, "+", "pk", $b.pk   ];
        @diffs.push: [ $!name, "-", "pk", self.pk ];
    }
    if self.unique != $b.unique {
        @diffs.push: [ $!name, "+", "unique", $b.unique   ];
        @diffs.push: [ $!name, "-", "unique", self.unique ];
    }
    if quietly ?self.references<table> and ?$b.references<table>
        and self.references<table>  ne $b.references<table>
        or  self.references<column> ne $b.references<column>
    {
        @diffs.push: [ $!name, "+", "references", $b.references   ];
        @diffs.push: [ $!name, "-", "references", self.references ];
    }
    @diffs
}
