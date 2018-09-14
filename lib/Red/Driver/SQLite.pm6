use DBIish;
use Red::Driver;
use Red::AST;
unit class Red::Driver::SQLite does Red::Driver;

has $!database = q<:memory:>;

method is-connected(--> True) {}

method dbh { $ //= DBIish.connect: "SQLite", :$!database }

method translate(Red::AST) { "SELECT 42", [] } # FIXME
