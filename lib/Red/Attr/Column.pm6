use Red::Column;

unit role Red::Attr::Column;
has             %.args;
has Red::Column $!column;

method perl { $!column.gist }

method column { $!column }

method create-column {
    $!column .= new: |%!args, :attr(self)
}
