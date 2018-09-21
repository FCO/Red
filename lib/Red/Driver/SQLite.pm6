use DBIish;
use Red::Driver;
use Red::AST;
use Red::Column;
use Red::AST::Infix;
use Red::AST::Select;
use Red::AST::Unary;
use Red::AST::Value;
unit class Red::Driver::SQLite does Red::Driver;

has $!database = q<:memory:>;
has $!dbh = DBIish.connect: "SQLite", :$!database;

class Statement {
    has $.statement;

    method execute(*@binds) { $!statement.execute: |@binds }
}

method prepare($query) {
    Statement.new: :dbh($!dbh.prepare: $query)
}

proto method translate(Red::AST) {*}

multi method translate(Red::AST::Select $_) {
    say .filter;
    my $tables = .tables.map({ .^table }).join: ", ";
    my $where  = self.translate: .filter;
    "SELECT * FROM $tables WHERE $where", []
}

multi method translate(Red::AST::Infix $_) {
    "{ self.translate: .left } { .op } { self.translate: .right }"
}

multi method translate(Red::Column $_) {
    .name
}

multi method translate(Red::AST::Cast $_) {
    when Red::AST::Value {
        qq|'{ .value }'|
    }
    default {
        self.translate: .value
    }
}

multi method translate(Red::AST::Value $_) {
    qq|'{ .value }'|
}
