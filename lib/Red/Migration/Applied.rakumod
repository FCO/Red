use Red;

#| Tracks which migrations have been applied to a database.
#| Used by `red migration apply` to know which up.sql files to run.
unit model Red::Migration::Applied is table<red_migrations>;

has UInt     $.id         is serial;
has UInt     $.version     is column{ :unique, :!nullable };
has Str      $.name        is column{ :!nullable };
has DateTime $.applied-at  is column = DateTime.now;
