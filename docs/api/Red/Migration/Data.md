Red::Migration::Data
--------------------

### sub fail

```raku
sub fail(
    Str $reason
) returns Mu
```

Raise a typed migration compilation error instead of falling back to runtime Raku execution.

### sub has-phasers

```raku
sub has-phasers(
    $block
) returns Bool
```

Detect block phasers on both older and newer RakuAST implementations.

### sub check-source

```raku
sub check-source(
    Str $source
) returns Mu
```

Reject unsupported declarations, phasers and interpolation before frontend parsing can execute compile-time effects. Transformation files accept a restricted SQL-translatable subset of Raku.

### sub required-columns

```raku
sub required-columns(
    $before,
    $after
) returns Array
```

Identify required additions and nullable-to-required changes on existing tables. Return their historical model, table and column names for draft generation and assignment validation.

### sub data-template

```raku
sub data-template(
    $before,
    $after
) returns Str
```

Generate migration.raku placeholders for columns requiring explicit data preparation. Suggested without modifiers preserve existing defined values.

### sub intermediate-schema

```raku
sub intermediate-schema(
    $before,
    $after
) returns Red::Migration::Snapshot
```

Build the schema available while data statements run. Keep existing columns and tables, add new storage, and defer required-column constraints and removals until afterward.

### sub sql-value

```raku
sub sql-value(
    $value,
    $driver
) returns Str
```

Encode a supported scalar as a dialect-safe SQL literal. Handle NULL, Booleans and finite numbers; use UTF-8 hexadecimal expressions for strings containing backslashes or NUL.

class Red::Migration::Data::Literal
-----------------------------------

Preserve a scalar Red expression together with its dialect-safe SQL literal representation.



Extend an offline backend with literal rendering that never leaves runtime bind parameters.

### method translate

```raku
method translate(
    Red::Migration::Data::Literal:D $value,
    $context?
) returns Mu
```

Render an already encoded literal without runtime bind parameters, regardless of the surrounding expression translation context.

class Red::Migration::Data::Compiler
------------------------------------

Lower the supported migration-file RakuAST into ordered SQL against historical model proxies.

### method children

```raku
method children(
    $node
) returns Array
```

Collect direct RakuAST children in source order for the migration-specific lowering pass.

### method literal

```raku
method literal(
    $value
) returns Mu
```

Wrap a scalar with its safely encoded SQL representation while retaining its Red expression type.

### method predicate

```raku
method predicate(
    $value
) returns Bool
```

Recognize supported Boolean conditions, including comparison, definedness and SQL membership or LIKE expressions.

### method name

```raku
method name(
    $name
) returns Str
```

Normalize a string or RakuAST identifier into the historical name used during declaration lookup.

### method literals

```raku
method literals(
    $expression
) returns Mu
```

Clone an expression tree with safely encoded literal nodes, preserving column references and expression structure.

### method sql

```raku
method sql(
    $expression
) returns Str
```

Translate a supported Red expression for this dialect and reject any unresolved runtime bind parameters.

### method field

```raku
method field(
    $model,
    Str $name
) returns Mu
```

Resolve a historical model column by its Raku accessor name. Unknown members fail before SQL is published.

### method method

```raku
method method(
    $call,
    $receiver
) returns Mu
```

Lower a supported ordinary column method or model accessor. Reject arbitrary method calls rather than executing application code.

### method expr

```raku
method expr(
    $node,
    $topic
) returns Mu
```

Lower a supported RakuAST scalar expression into Red SQL expressions, using the current model or topicalized column as its topic.

### method statements

```raku
method statements(
    $block,
    $model,
    Str $kind,
    $topic = Code.new,
    $condition = Any
) returns Mu
```

Lower migration assignments or explicit populate inserts in source order. Preserve modifier topic semantics and conditions; conditional blocks are restricted to one assignment to avoid re-evaluating a mutated predicate.

### method compile

```raku
method compile(
    $ast
) returns Hash
```

Compile ordered Model.^migration and Model.^populate declarations into SQL statements and a set of assigned columns. Reject unknown historical models and unsupported declaration shapes.

### sub compile-data

```raku
sub compile-data(
    $before,
    $after,
    Str $source,
    $backend,
    Str $dialect
) returns Hash
```

Compile migration.raku against synthetic models reconstructed from the previous and target snapshots. Return ordered SQL and assigned columns without connecting to a target database or invoking application populate methods.

