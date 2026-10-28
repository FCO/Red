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
    @!constraints = @constraints.map(-> $constraint {
        my @members = $constraint.^can('columns') ?? $constraint.columns !! $constraint.list;
        @members.map({ $_ ~~ Str ?? $_ !! .column.name }).Array
    });
    my %single := set @!constraints.grep(*.elems == 1).map(*.head);
    for @columns -> $col {
        $col.table = self;
        $col.unique = True if %single{$col.name};
        if $col.references<table>.defined {
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
    my Str $a-name = self.defined && self.exists ?? $!name  // "<no-table>" !! "<no-table>";
    my Str $b-name = $b.defined && $b.exists ?? $b.name // Str !! Str;

    my @a = self.defined && self.exists ?? @!columns.sort:  *.name !! ();
    my @b = $b.defined && $b.exists ?? $b.columns.sort: *.name !! ();

    if $a-name ne ($b-name // "") {
        if !self.defined && !$b-name.defined {
            die "No from and to table... it should never happen..."
        }
        if !self.defined || !self.exists || !$!name.defined {
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

    my @old = @!constraints.grep(*.elems > 1).map(*.raku).sort;
    my @new = $b.constraints.grep(*.elems > 1).map(*.raku).sort;
    if @old.raku ne @new.raku {
        @diffs.push: [$a-name, '+', 'constraints', $b.constraints.Array];
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
