use Red::Column;

unit role Red::Attr::Column;
has             %.args;
has Red::Column $!column;

method perl { $.column.gist }

method column(--> Red::Column:D) {
    $!column.DEFINITE ?? $!column !! Red::Column.new: |%!args, :attr(self)
}

method create-column(Mu $model = Nil) {
    $!column = Red::Column.new: |%!args, :attr($model !=== Nil ?? self.clone: :package($model) !! self)
}
