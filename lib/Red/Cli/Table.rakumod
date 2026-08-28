use Red::Utils;
use Red::Cli::Column;
use Red::Cli::Relationship;
unit class Red::Cli::Table;

has Str  $.name;
has Str  $.model-name = try { snake-to-camel-case $!name };
has      @.columns;
has      @.constraints;
has      @.relationships;
has Bool $.exists = True;

submethod TWEAK(:@columns, :@constraints) {
    my @single-constraints;
    for @constraints -> @cols {
        @single-constraints.push: @cols.head.column.name if +@cols == 1
    }
    my %single := set @single-constraints;
    for @columns -> $col {
        $col.table = self;
        $col.unique = True if %single{$col.name};
        with $col.references {
            @!relationships.push: Red::Cli::Relationship.new: :id($col)
        }
    }
}

multi method gist(::?CLASS:U:) { "({ self.^name})" }
multi method gist(::?CLASS:D:) {
    "{self.^name}.new(:name<{$!name}>, :columns[{ @!columns>>.gist.join: ", " }])"
}

multi method model-definition($ where so *)  { "unit model { $!model-name };\n" }
multi method model-definition($ where not *) { "model { $!model-name } \{" }
multi method model-end($ where so *)  { "" }
multi method model-end($ where not *) { "\}" }

method to-code(Str :$schema-class, Bool :$no-relationships) {
    my $unit = not $schema-class.defined;
    qq:to/END/;
    { self.model-definition: $unit }
    { do for @!columns -> $col {
        $col.to-code: :$schema-class
    }.join("\n").indent: $unit ?? 0 !! 4 }
    { "\n" ~ do for @!relationships -> $rel {
        $rel.to-code: :$schema-class
    }.join("\n").indent: $unit ?? 0 !! 4 unless $no-relationships}
    { self.model-end: $unit }
    END
}

method diff($b) {
    my @diffs;
    my Str $a-name = self.defined ?? $!name  // "<no-table>" !! "<no-table>";
    my Str $b-name = $b.defined   ?? $b.name // Str !! Str;

    my @a = self ?? @!columns.sort:  *.name !! ();
    my @b = $b   ?? $b.columns.sort: *.name !! ();

    if $a-name ne ($b-name // "") {
        if !self.defined && !$!name.defined && !$b-name.defined {
            die "No from or to table... it should never happen..."
        }
        if !self.defined || !$!name.defined {
            @diffs.push: [ $a-name, "+", "table", $b ];
            return @diffs
        } elsif !$b-name.defined {
            @diffs.push: [ $a-name, "-", "table", self ];
            return @diffs
        } else {
            @diffs.push: [ $a-name, "+", "name", $b-name ];
            @diffs.push: [ $a-name, "-", "name", $a-name ];
        }
    }

    while @a > 0 and @b > 0 {
        if @a.head.name eq @b.head.name {
            my $a = @a.shift;
            my $b = @b.shift;
            for $a.diff: $b -> @d {
                @diffs.push: [ $a-name, |@d ]
            }
        } elsif @b.head.name lt @a.head.name {
            @diffs.push: [ $a-name, "+", "col", @b.shift ];
        } elsif @a.head.name lt @b.head.name {
            @diffs.push: [ $a-name, "-", "col", @a.shift ];
        }
    }
    @diffs.push: [ $a-name, "+", "col", $_ ] for @b;
    @diffs.push: [ $a-name, "-", "col", $_ ] for @a;
    @diffs
}
