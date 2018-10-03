use DBIish;
use Red::AST;
use Red::Driver;
use Red::Statement;
use Red::AST::Value;
use Red::AST::Select;
use Red::AST::Infixes;
use Red::AST::Function;
use Red::Driver::CommonSQL;
use Red::AST::LastInsertedRow;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $!database = q<:memory:>;
has $!dbh = DBIish.connect: "SQLite", :$!database;

class Statement does Red::Statement {
    method stt-exec($stt, *@bind) {
        $stt.execute: |@bind;
        $stt
    }
    method stt-row($stt) { $stt.row: :hash }
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    do unless $*RED-DRY-RUN {
        my $stt = self.prepare: $sql;
        $stt.predefined-bind;
        $stt.binds = @bind;
        $stt
    }
}

multi method prepare(Str $query) {
    self.debug: $query;
    Statement.new: :driver(self), :statement($!dbh.prepare: $query)
}

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context?) {
    .value ?? 1 !! 0
}

multi method translate(Red::AST::Not $_, $context?) {
	my $val = self.translate: .value, $context;
    "($val == 0 OR $val IS NULL)"
}

multi method translate(Red::AST::LastInsertedRow $_, $context?) {
    my $of     = .of;
    my $filter = Red::AST::Eq.new: $of.^id.head.column, Red::AST::Function.new: :func<last_insert_rowid>;
    self.translate(Red::AST::Select.new: :$of, :$filter, :1limit)
}

multi method translate(Red::Column $_, "column-auto-increment") { "AUTOINCREMENT" if .auto-increment }

multi method default-type-for(Red::Column $ where .attr.type ~~ Bool           --> "integer")        {}
multi method default-type-for(Red::Column $ where .attr.type ~~ one(Int, Bool) --> "integer")       {}
