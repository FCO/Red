use Red;
unit model Red::Migration::Column is table<red_migration_column>;

has UInt    $!id                is serial;
has Str     $.name              is column is required;
has Str     $.type              is column is required;
has Str     $.references-table  is column{ :nullable };
has Str     $.references-column is column{ :nullable };
has Bool    $.is-id             is column = False;
has Bool    $.is-auto-increment is column = False;
has Bool    $.is-nullable       is column = False;

has UInt    $.table-id          is referencing{ :column<id>, :model<Red::Migration::Table>}
has         $.table             is relationship( { .table-id }, :model<Red::Migration::Table>)
