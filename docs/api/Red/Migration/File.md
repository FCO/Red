Red::Migration::File
--------------------

class Red::Migration::File
--------------------------

Persist one SQL file checkpoint in red_migration_files. Checksums identify changes to executed files, and statement counts describe execution progress rather than a guarantee that every statement committed on every database backend.

