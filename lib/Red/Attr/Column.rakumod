use Red::Column;

unit role Red::Attr::Column;
has             %.args;
has Red::Column $!column;

my class HydrationColumn {
    has Attribute $.attr is required;
    has Str $.attr-name is required;
    has Str $.name is required;
    has &.inflate is required;
}

# Row loading needs names and an inflator, not the full SQL expression object.
# Read live metadata on each call; specialized columns retain their own behavior.
method hydration-column(--> Any:D) {
    return self.column if $!column.DEFINITE || self.type.^find_method('red-type-db-methods');
    HydrationColumn.new(
        :attr(self), :attr-name(self.column-attr-name),
        :name((%!args<name>:exists) ?? %!args<name>
            !! Red::Column.column-formatter(self.name.substr(2))),
        :inflate((%!args<inflate>:exists) ?? %!args<inflate>
            !! Red::Column.inflator-for(self))
    )
}

method column-attr-name(--> Str) {
    return $!column.attr-name if $!column.DEFINITE;
    (%!args<attr-name>:exists) ?? %!args<attr-name> !! self.name.substr(2)
}

method column-id(--> Bool:D) {
    return so $!column.id if $!column.DEFINITE;
    my Bool $id = %!args<id> // False;
    so $id
}

method raku { $.column.gist }

method column(--> Red::Column:D) {
    $!column.DEFINITE ?? $!column !! Red::Column.new: |%!args, :attr(self)
}

method create-column(Mu $model = Nil) {
    $!column = Red::Column.new: |%!args, :attr($model !=== Nil ?? self.clone: :package($model) !! self)
}
