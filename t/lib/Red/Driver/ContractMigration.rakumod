use Red::Driver::SQLite;
# A deliberately unknown backend name exercises capability dispatch in migrations.
unit class Red::Driver::ContractMigration is Red::Driver::SQLite;
