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
use X::Red::Exceptions;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $.database = q<:memory:>;
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

multi method translate(Red::AST::Not $_ where { .value ~~ Red::Column and .value.attr.type !~~ Str }, $context?) {
	my $val = self.translate: .value, $context;
    "($val == 0 OR $val IS NULL)"
}

multi method translate(Red::AST::So $_ where { .value ~~ Red::Column and .value.attr.type !~~ Str }, $context?) {
	my $val = self.translate: .value, $context;
    "($val <> 0 AND $val IS NOT NULL)"
}

multi method translate(Red::AST::Not $_ where { .value ~~ Red::Column and .value.attr.type ~~ Str }, $context?) {
	my $val = self.translate: .value, $context;
    "($val == '' OR $val IS NULL)"
}

multi method translate(Red::AST::So $_ where { .value ~~ Red::Column and .value.attr.type ~~ Str }, $context?) {
	my $val = self.translate: .value, $context;
    "($val <> '' AND $val IS NOT NULL)"
}

multi method translate(Red::AST::RowId $_, $context?) { "_rowid_" }

multi method translate(Red::AST::LastInsertedRow $_, $context?) {
    my $of     = .of;
    my $filter = Red::AST::Eq.new: Red::AST::RowId, Red::AST::Function.new: :func<last_insert_rowid>;
    self.translate(Red::AST::Select.new: :$of, :$filter, :1limit)
}

multi method translate(Red::Column $_, "column-auto-increment") { "AUTOINCREMENT" if .auto-increment }

#multi method default-type-for(Red::Column $ where .attr.type ~~ Mu             --> Str:D) {"varchar(255)"}
multi method default-type-for(Red::Column $ where .attr.type ~~ Bool           --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ one(Int, Bool) --> Str:D) {"integer"}

multi method translate(Red::AST::Minus $ast, "multi-select-op") { "EXCEPT" }

multi method map-exception(Exception $x where { .code == 19 and .native-message.starts-with: "UNIQUE constraint failed:" }) {
    X::Red::Driver::Mapped::Unique.new:
        :driver<SQLite>,
        :orig-exception($x),
        :fields($x.native-message.substr(26).split: /\s* "," \s*/)
}

