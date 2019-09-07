use Red;
unit model Red::Migration::Table is table<red_migration_table>;

has UInt    $!id            is serial;
has Str     $.name          is column is required;
has Version $.version       is column is required;

has Instant $.created-at    is column = now;

has UInt    $.migration-id  is referencing{ :column<id>, :model<Red::Migration::Migration>};
has         $.migration     is relationship( { .migration-id }, :model<Red::Migration::Migration> );
has         @.columns       is relationship( { .table-id }, :model<Red::Migration::Column>);

::?CLASS.^add-unique-constraint: { .name, .version };
