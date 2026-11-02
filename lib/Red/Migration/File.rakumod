use Red;
=head2 Red::Migration::File

#| Persist one SQL file checkpoint in red_migration_files. Checksums identify changes to executed
#| files, and statement counts describe execution progress rather than a
#| guarantee that every statement committed on every database backend.
unit model Red::Migration::File is table<red_migration_files>;

has Str $.id is id;
has Str $.migration-id is column;
has Str $.direction is column;
has Str $.file is column;
has Str $.checksum is column;
has Str $.state is rw is column;
has Int $.completed-statements is rw is column;
