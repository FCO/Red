use Red::Driver::Cache;
use Red::AST::Insert;

unit role Red::Driver::CacheInvalidateOnWrite;

method driver { ... }

#multi method invalidate(Str :$table!) { ... }

multi method invalidate(Str :$table!, *%columns where .elems > 0) {
    self.invalidate: :$table
}

multi method prepare(Red::AST::Insert $ast ) {
    ENTER self.invalidate: :table($ast.into.^table), |$ast.values;
    $.driver.prepare: $ast
}
