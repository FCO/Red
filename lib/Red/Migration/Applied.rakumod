use Red;
=head2 Red::Migration::Applied

#| Store version execution state in red_migrations, including ancestry, direction, checksums and
#| application or reversion timestamps. The migration manager owns these bookkeeping records.
unit model Red::Migration::Applied is table<red_migrations>;

has Str $.id is id;
has Str $.predecessor is column;
has Str $.up-checksum is column;
has Str $.down-checksum is column;
has Str $.state is rw is column;
has Str $.direction is rw is column;
has Str $.applied-at is rw is column;
has Str $.reverted-at is rw is column;
has Int $.completed-statements is rw is column;
