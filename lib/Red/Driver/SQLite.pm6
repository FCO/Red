use DBIish;
use Red::Driver;
use Red::AST;
unit class Red::Driver::SQLite does Red::Driver;

has $!database = q<:memory:>;

method dbh { $ //= DBIish.connect: "SQLite", :$!database }

method translate(Red::AST $ast) {
    say $ast;
    "SELECT 42 as value", []
} # FIXME
