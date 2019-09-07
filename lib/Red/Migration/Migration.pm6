use Red;
unit model Red::Migration::Migration is table<red_migration_version>;

has UInt    $!id                is id;
has Version $.version           is column{ :unique };

has         @.afected-tables    is relationship{ { .migration-id }, :model<Red::Migration::Table> }
