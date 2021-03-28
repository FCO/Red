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
use Red::AST::JsonItem;
use Red::AST::JsonRemoveItem;
use X::Red::Exceptions;
use UUID;
use Red::SchemaReader;
use Red::Driver::SQLite::SchemaReader;
use Red::Type::Json;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $.database = q<:memory:>;
has DBDish::SQLite::Connection $!dbh;

method schema-reader { Red::Driver::SQLite::SchemaReader }

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
    Statement.new: :driver(self), :statement($!dbh.prepare: $query);
}

method create-schema(%models where .values.all ~~ Red::Model) {
    do for %models.kv -> Str() $name, Red::Model $model {
        $name => $model.^create-table
    }
}

multi method join-type("outer") { die "'OUTER JOIN' is not supported by SQLite" }
multi method join-type("right") { die "'RIGHT JOIN' is not supported by SQLite" }

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context? where $_ ne "bind") {
    (.value ?? 1 !! 0) => []
}

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, $context? where { !.defined || $_ ne "bind" }) {
    self.translate:
            Red::AST::Function.new(:func<JSON>, :args[ ast-value .value, :type(Str) ]),
            $context
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
    self.translate(Red::AST::Select.new: :$of, :table-list[$of], :$filter, :1limit)
}

multi method translate(Red::Column $_, "column-auto-increment") { (.auto-increment ?? "AUTOINCREMENT" !! "") => [] }

multi method translate(Red::Column $_, "column-comment") {
    (" { self.comment-starter } $_\n" with .comment) => []
}

multi method translate(Red::AST::TableComment $_, $context?) {
        (" { self.comment-starter } { .msg }" => []) with $_
}

multi method translate(Red::AST::JsonRemoveItem $_, $context?) {
    self.translate:
            Red::AST::Function.new:
                    :func<JSON_REMOVE>,
                    :args[
                        .left,
                        ast-value('$' ~ self.prepare-json-path-item: .right.value)
                    ],
                    :returns(Json),
}

multi method translate(Red::AST::JsonItem $_, $context?) {
    self.translate:
            Red::AST::Function.new:
                    :func<JSON_EXTRACT>,
                    :args[
                        .left,
                        ast-value('$' ~ self.prepare-json-path-item: .right.value)
                    ],
                    :returns(Json),
}

multi method translate(Red::AST::Value $_ where { .type ~~ Pair and .value.key ~~ Red::AST::JsonItem}, "update") {
    my $value = Red::AST::Function.new:
            :func<JSON_SET>,
            :args[
                .value.key.left,
                ast-value('$' ~ self.prepare-json-path-item(.value.key.right.value)),
                .value.value
            ],
            :returns(Json),
    ;
    self.translate: ast-value(.value.key.left => $value), "update"
}

multi method translate(Red::AST::Minus $ast, "multi-select-op") { "EXCEPT" => [] }

method comment-on-same-statement { True }

#multi method default-type-for(Red::Column $ where .attr.type ~~ Mu             --> Str:D) {"varchar(255)"}
multi method default-type-for(Red::Column $ where .attr.type ~~ Bool            --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ one(Int, Bool)  --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ UUID            --> Str:D) {"varchar(36)"}
multi method default-type-for(Red::Column $ where .attr.type ~~ Json            --> Str:D) {"json"}
#multi method default-type-for(Red::Column $ where .attr.type ~~ Any             --> Str:D) {"varchar(255)"}
multi method default-type-for(Red::Column $                                     --> Str:D) {"varchar(255)"}
multi method default-type-for($ --> Str:D) is default {"varchar(255)"}


multi method map-exception(X::DBDish::DBError $x where { (.?code == 19 or .?code == 1555 or .?code == 2067) and .native-message.starts-with: "UNIQUE constraint failed:" }) {
    X::Red::Driver::Mapped::Unique.new:
        :driver<SQLite>,
        :orig-exception($x),
        :fields($x.native-message.substr(26).split: /\s* "," \s*/)
}

multi method map-exception(X::DBDish::DBError $x where { .?code == 1 and .native-message ~~ m:i/^table \s+ $<table>=(\w+) \s+ already \s+ exists/ }) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<SQLite>,
            :orig-exception($x),
            :table($<table>.Str)
}

multi method map-exception(X::DBDish::DBError $x where { .?code == 1 and .native-message ~~ m:i/^table \s+ \"$<table>=(\w+)\" \s+ already \s+ exists/ }) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<SQLite>,
            :orig-exception($x),
            :table($<table>.Str)
}
