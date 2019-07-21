use Red::SchemaReader;
use Red::Driver::SQLite::SQLiteMaster;

unit class Red::Driver::SQLite::SchemaReader;
also does Red::SchemaReader;

method sqlite-master { Red::Driver::SQLite::SQLiteMaster }

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
        make Red::Cli::Column.new(
            $<column-name>.made,
            $<type>.made,
            ($<modifier>.made // True),
            |$<index-mod>.made<pk unique references>
        )
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

method tables-names       { self.sqlite-master.tables.map: *.name }
method indexes-of($table) { self.sqlite-master.find-table($table).indexes }
method table-definition($table) {
   my $sql = self.sqlite-master.find-table($table).sql;
   self.table-definition-from-create-table: $sql
}
method table-definition-from-create-table($sql) {
   SQL::CreateTable.parse($sql, :actions(SQL::CreateTable::Action)).made;
}
