use DBIish;
use Red::Driver;
use Red::Driver::CommonSQL;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $!database = q<:memory:>;
has $!dbh = DBIish.connect: "SQLite", :$!database;

class Statement {
    has $.statement;

    method execute(*@binds) { $!statement.execute: |@binds }
}

method prepare($query) {
    Statement.new: :dbh($!dbh.prepare: $query)
}

