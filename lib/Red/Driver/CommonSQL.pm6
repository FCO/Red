use Red::AST;
use Red::Model;
use Red::Column;
use Red::AST::Infix;
use Red::AST::Select;
use Red::AST::Unary;
use Red::AST::Value;
use Red::AST::Insert;
use Red::AST::Update;
use Red::AST::Delete;
use Red::AST::Function;
use Red::AST::CreateTable;
use Red::AST::LastInsertedRow;
use Red::Driver;
unit role Red::Driver::CommonSQL does Red::Driver;

proto method translate(Red::AST, $?) {*}

multi method translate(Red::AST::Select $ast, $context?) {
    my $sel    = do given $ast.of {
        when Red::Model {
            .^columns.keys.map({ self.translate: .column, "select" }).join: ", ";
        }
        default {
            self.translate: $_, "select"
        }
    }
    my $tables = $ast.tables.grep({ not .?no-table }).unique
        .map({ .^table }).join: ", "                        if $ast.^can: "tables";
    my $where  = self.translate: $ast.filter                if $ast.?filter;
    my $order  = $ast.order.map({ .name }).join: ", "       if $ast.?order;
    my $limit  = $ast.limit;
    quietly "SELECT\n{
        $sel ?? $sel.indent: 3 !! "*"
    }\n{
        "FROM\n{ .indent: 3 }" with $tables
    }\n{
        "WHERE\n{ .indent: 3 }" with $where
    }{
        "\nORDER BY\n{ .indent: 3 }" with $order
    }{
        "\nLIMIT $_" with $limit
    }", []
}

multi method translate(Red::AST::Function $_, $context?) {
    "{ .func }({ .args.map({ self.translate: $_ }).join: ", " })"
}

multi method translate(Red::AST::Infix $_, $context?) {
    "{ self.translate: .left, $context } { .op } { self.translate: .right, $context }"
}

multi method translate(Red::AST::Not $_, $context?) {
    "not { self.translate: .value, $context }"
}

multi method translate(Red::Column $_, "select") {
    qq[{.name} {qq<as "{.attr-name}"> unless .name eq .attr-name}]
}

multi method translate(Red::Column $_, $context?) {
    .name
}

multi method translate(Red::AST::Cast $_, $context?) {
    when Red::AST::Value {
        qq|'{ .value }'|
    }
    default {
        self.translate: .value, $context
    }
}

multi method translate(Red::AST::Value $_ where .type ~~ Str, $context?) {
    quietly qq|'{ .value.subst: "'", q"''", :g }'|
}

multi method translate(Red::AST::Value $_ where .type ~~ Instant, $context?) {
    quietly qq|{ .value.?to-posix.head }|
}

multi method translate(Red::AST::Value $_ where .type !~~ Str, $context?) {
    quietly qq|{ .value }|
}

multi method translate(Red::Column $_, "create-table") {
    <
        column-name
        column-type
        nullable-column
        column-pk
        column-auto-increment
        column-references
    >
        .map(-> $context {
            self.translate: $_, $context
        })
        .grep( *.defined )
        .join: " "
}

multi method translate(Red::Column $_, "column-name")           { .name // "" }

multi method translate(Red::Column $_, "column-type")           { self.default-type-for: $_ }

multi method translate(Red::Column $_, "nullable-column")       { .nullable ?? "NULL" !! "NOT NULL" }

multi method translate(Red::Column $_, "column-pk")             { "primary key" if .id }

multi method translate(Red::Column $_, "column-auto-increment") { "auto_increment" if .auto-increment }

multi method translate(Red::Column $_, "column-references")     {
    my $ref = .() with .references;
    "references { $ref.class.^table }({ $ref.name })" with $ref
}

multi method translate(Red::AST::CreateTable $_, $context?) {
    "CREATE TABLE {
        .name
    }(\n{
        .columns.map({ self.translate: $_, "create-table" }).join(",\n").indent: 3
    }\n)", []
}

multi method translate(Red::AST::Insert $_, $context?) {
    my @values = .values.grep({ .value.value.defined });
    "INSERT INTO {
        .into.^table
    }(\n{
        @values>>.key.join(",\n").indent: 3
    }\n)\nVALUES(\n{
        @values>>.value.map(-> $val { self.translate: $val, "insert" }).join(",\n").indent: 3
    }\n)", []
}

multi method translate(Red::AST::Delete $_, $context?) {
    "DELETE FROM { .from }\n{ "WHERE { self.translate: $_ }" with .filter }", []
}

multi method translate(Red::AST::Update $_, $context?) {
    "UPDATE { .into } SET\n{ .values.kv.map(-> $col, $val { "{$col} = {self.translate: $val, "update"}" }).join(",\n").indent: 3 }\nWHERE { self.translate: .filter }", []
}

multi method translate(Red::AST::LastInsertedRow $_, $context?) { "", [] }

multi method translate(Red::AST:U $_, $context?) { Empty, [] }

multi method default-type-for(Red::Column $ where .attr.type ~~ Instant     --> "real")           {}
multi method default-type-for(Red::Column $ where .attr.type ~~ Mu          --> "varchar(255)")   {}
multi method default-type-for(Red::Column $ where .attr.type ~~ Str         --> "varchar(255)")   {}
multi method default-type-for(Red::Column $ where .attr.type ~~ Int         --> "integer")        {}
multi method default-type-for(Red::Column $ where .attr.type ~~ Bool        --> "boolean")        {}
multi method default-type-for(Red::Column                                   --> "varchar(255)")   {}


multi method inflate(Num $value, Instant :$to) { Instant.from-posix: $value }
