use Red;
use Red::DriverTable;
unit model Red::Driver::SQLite::SQLiteMaster is table<sqlite_master>;
also does Red::DriverTable;

#use Grammar::Tracer::Compact;
grammar SQL::CreateTable {
    rule  TOP                      { :i CREATE TABLE <table-name=.name> '(' ~ ')' <column>+ %% [ "," ] }
    token name                     { :i \w+ }
    rule  column                   { :i <column-name=.name> <type=.name> <modifier>? <index-mod>? }
    proto rule modifier            {*}
    multi rule modifier:<null>     { :i NULL }
    multi rule modifier:<not-null> { :i NOT NULL }
    proto rule index-mod           {*}
    multi rule index-mod:<pk>      { :i PRIMARY KEY }
    multi rule index-mod:<fk>      { :i REFERENCES <table-name=.name> '(' ~ ')' <column-name=.name> }
    multi rule index-mod:<unique>  { :i UNIQUE }
    proto rule index               {*}
    multi rule index:<pk>          { :i PRIMARY KEY '(' ~ ')' <column-name=.name>+ % "," }
    multi rule index:<fk>          { :i FOREIGN KEY <local-column-name=.name> REFERENCES '(' ~ ')' <column-name=.name>+ % "," }
    multi rule index:<unique>      { :i UNIQUE '(' ~ ')' <column-name=.name>+ % "," }
}

class SQL::CreateTable::Action {
    use Red::Cli::Table;
    use Red::Cli::Column;
    method TOP($/)                 { make Red::Cli::Table.new: name => $<table-name>.made, columns => $<column>».made }
    method name($/)                { make ~$/ }
    method column($/)              {
        make Red::Cli::Column.new( $<column-name>.made, $<type>.made, ($<modifier>.made // True), |$<index-mod>.made<pk unique references> )
    }
    method modifier:<null>($/)     { make ( :nullable ) }
    method modifier:<not-null>($/) { make ( :!nullable ) }
    method index-mod:<pk>($/)      { make ( :pk ) }
    method index-mod:<fk>($/)      { make ( :references{ table => $<table-name>.made, column => $<column-name>.made } ) }
    method index-mod:<unique>($/)  { make ( :unique ) }
    method index:<pk>($/)          { ... }
    method index:<fk>($/)          { ... }
    method index:<unique>($/)      { ... }
}

has Str      $.type      is column;
has Str      $.name      is id;
has Str      $.table     is column{:name<tbl_name>, :references{ ::?CLASS.name }};
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

method tables-names       { self.tables.map: *.name }
method indexes-of($table) { self.find-table($table).indexes }
method table-definition($table) {
   my $sql = self.find-table($table).sql;
   SQL::CreateTable.parse($sql, :actions(SQL::CreateTable::Action)).made;
}
