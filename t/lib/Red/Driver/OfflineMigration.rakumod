use Red::Driver::SQLite;

unit class Red::Driver::OfflineMigration is Red::Driver::SQLite;

method new(|) { die 'Offline migration must not construct a driver' }
