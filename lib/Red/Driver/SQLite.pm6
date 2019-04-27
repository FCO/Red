use DBIish;
need DBDish::SQLite::Connection;
use Red::AST;
use Red::Driver;
use Red::Statement;
use Red::AST::Value;
use Red::AST::Select;
use Red::AST::Infixes;
use Red::AST::Function;
use Red::Driver::CommonSQL;
use Red::AST::LastInsertedRow;
use Red::AST::TableComment;
use X::Red::Exceptions;
use UUID;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $.database = q<:memory:>;
has DBDish::SQLite::Connection $!dbh;


submethod BUILD(DBDish::SQLite::Connection :$!dbh, Str :$!database = q<:memory:> ) {
}

submethod TWEAK() {
    $!dbh //= DBIish.connect: "SQLite", :$!database;
}

class Statement does Red::Statement {
    method stt-exec($stt, *@bind) {
        $.driver.debug: (@bind || @!binds);
        $stt.execute:  |(@bind || @!binds);
        $stt
    }
    method stt-row($stt) { $stt.row: :hash }
}

multi method prepare(Str $query) {
    CATCH {
        default {
            self.map-exception($_).throw
        }
    }
    self.debug: $query;
    Statement.new: :driver(self), :statement($!dbh.prepare: $query)
}

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context?) {
    (.value ?? 1 !! 0) => []
}

multi method translate(Red::AST::Not $_ where { .value ~~ Red::Column and .value.attr.type !~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val == 0 OR $val IS NULL)" => @bind
}

multi method translate(Red::AST::So $_ where { .value ~~ Red::Column and .value.attr.type !~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val <> 0 AND $val IS NOT NULL)" => @bind
}

multi method translate(Red::AST::Not $_ where { .value ~~ Red::Column and .value.attr.type ~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val == '' OR $val IS NULL)" => @bind
}

multi method translate(Red::AST::So $_ where { .value ~~ Red::Column and .value.attr.type ~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val <> '' AND $val IS NOT NULL)" => @bind
}

multi method translate(Red::AST::RowId $_, $context?) { "_rowid_" => [] }

multi method translate(Red::AST::LastInsertedRow $_, $context?) {
    my $of     = .of;
    my $filter = Red::AST::Eq.new: Red::AST::RowId, Red::AST::Function.new: :func<last_insert_rowid>;
    self.translate(Red::AST::Select.new: :$of, :$filter, :1limit)
}

multi method translate(Red::Column $_, "column-auto-increment") { (.auto-increment ?? "AUTOINCREMENT" !! "") => [] }

multi method translate(Red::Column $_, "column-comment") {
    (" { self.comment-starter } $_\n" with .comment) => []
}

multi method translate(Red::AST::TableComment $_, $context?) {
        (" { self.comment-starter } { .msg }" => []) with $_
}

method comment-on-same-statement { True }

#multi method default-type-for(Red::Column $ where .attr.type ~~ Mu             --> Str:D) {"varchar(255)"}
multi method default-type-for(Red::Column $ where .attr.type ~~ Bool           --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ one(Int, Bool) --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ UUID        --> Str:D) {"varchar(36)"}

multi method translate(Red::AST::Minus $ast, "multi-select-op") { "EXCEPT" => [] }

multi method map-exception(Exception $x where { .?code == 19 and .native-message.starts-with: "UNIQUE constraint failed:" }) {
    X::Red::Driver::Mapped::Unique.new:
        :driver<SQLite>,
        :orig-exception($x),
        :fields($x.native-message.substr(26).split: /\s* "," \s*/)
}

multi method map-exception(Exception $x where { .?code == 1 and .native-message ~~ /^table \s+ $<table>=(\w+) \s+ already \s+ exists/ }) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<SQLite>,
            :orig-exception($x),
            :table($<table>.Str)
}