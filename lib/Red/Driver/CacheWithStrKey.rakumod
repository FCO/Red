use Red::Driver::Cache;
use X::Red::Exceptions;
use Red::AST;
use Red::AST::Unary;
use Red::AST::Select;
use Red::AST::Infix;
use Red::AST::Value;
use Red::AST::LastInsertedRow;

unit role Red::Driver::CacheWithStrKey does Red::Driver::Cache;

method get-from-cache(Str)  { ... }
method set-on-cache(Str, @) { ... }

multi method get-from-cache(Red::AST $ast)  {
    CATCH {
        default {
            .say
        }
    }
    my Str $key = self.translate-key: $ast;
    self.get-from-cache: $key, :$ast
}

multi method set-on-cache(Red::AST $ast, @data) {
    my Str $key = self.translate-key: $ast;
    self.set-on-cache: $key, @data, :$ast
}

multi method translate-key(Red::AST::Cast $_, $context?)  {
    "{ self.translate-key: .value }::{ .type }"
}

multi method translate-key(Red::AST::LastInsertedRow $_, $context?)  {
    X::Red::Driver::Cache::DoNotCache.new.throw
}

multi method translate-key(Red::Column $_, $context?)  {
    (.computation // $_).gist.subst: /\s+/, "_", :g
}

multi method translate-key(Red::Model:U $_, "table-list")  {
    .^table
}

multi method translate-key(Red::Model:U $_, "of")  {
    .^columns>>.column.map({ self.translate-key: $_, "of" }).join: "|"
}

multi method translate-key(Red::AST::Infix $_, $context)  {
    "{ self.translate-key: .left, $context }_{ .op }_{ self.translate-key: .right, $context }"
}

multi method translate-key(Red::AST::Value $_, $context)  {
    .value.Str
}

multi method translate-key(Red::AST::Select $_, $context?)  {
    (
        "CACHED_SELECT",
        self.translate-key(.of, "of"),
        "FROM",
        .tables.grep({ not .?no-table }).unique.map({ self.translate-key: $_, "table-list" }).join("|"),
        (|(
            "WHERE",
            self.translate-key($_, "filter"),
        ) with .filter),
        (|(
            "ORDER_BY",
            .order.map({ self.translate-key: $_, "order" }).join: "|"
        ) if .order),
        |( "LIMIT", .limit if .limit),
        |( "OFFSET", .offset if .offset),
    ).join: ":"
}

