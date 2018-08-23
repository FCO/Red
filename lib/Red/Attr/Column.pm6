use Red::Column;

unit role Red::Attr::Column;
has Red::Column $.column;

method perl { $!column.gist }
