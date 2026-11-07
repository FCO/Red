use Red;

#| Audit an explicit reconciliation of a partially executed migration. Observed execution
#| counters and checkpoints remain evidence, never an assertion about committed SQL effects.
unit model Red::Migration::Resolution is table<red_migration_resolutions>;

has Str $.id is id;
has Str $.migration-id is column;
has Str $.before-state is column;
has Str $.after-state is column;
has Str $.direction is column;
has Str $.reason is column{ :type<text> };
has Str $.resolved-at is column;
has Str $.verification is column;
has Str $.version-data is column{ :type<text> };
has Str $.checkpoint-data is column{ :type<text> };
