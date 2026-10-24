use Red::Column;

unit role Red::Attr::Column;
has             %.args;
has Red::Column $!column;

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
