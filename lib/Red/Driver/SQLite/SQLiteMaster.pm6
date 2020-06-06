use Red;
unit model Red::Driver::SQLite::SQLiteMaster is table<sqlite_master>;

has Str      $.type      is column;
has Str      $.name      is id;
has Str      $.table     is column{:name<tbl_name>, :references(*.name), :model-name(::?CLASS.^name)};
has Int      $.root-page is column<rootpage>;
has Str      $.sql       is column;
has ::?CLASS @.children  is relationship{ .table }

method tables(::?CLASS:U:)   { self.^all.grep: *.is-table }

multi method indexes(::?CLASS:U:) { ::?CLASS.^all.grep: *.is-index }
multi method indexes(::?CLASS:D:) { self.children.grep: *.is-index }

method is-table              { self.type eq "table" }
method is-index              { self.type eq "index" }

method find-table(::?CLASS:U: Str $name) { self.tables.first:  *.name eq $name }
method find-index(::?CLASS:U: Str $name) { self.indexes.first: *.name eq $name }
