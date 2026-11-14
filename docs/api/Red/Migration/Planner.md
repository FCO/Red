Red::Migration::Planner
-----------------------

### method error

```raku
method error(
    Str $reason
) returns Mu
```

Raise a typed error explaining why a schema operation cannot be generated safely.

### method q

```raku
method q(
    Str $name
) returns Mu
```

Quote a SQL identifier using the selected backend conventions.

### method capture

```raku
method capture(
    @models
) returns Red::Migration::Snapshot
```

Capture configured model schemas, indexes and constraints for this dialect. Reject unsupported model kinds, defaults and reserved bookkeeping table names.

### method column

```raku
method column(
    $col,
    Bool :$single-pk = Bool::False,
    Str :$table = ""
) returns Str
```

Render a column definition with its nullability, uniqueness and supported automatic-primary-key syntax for this dialect.

### method create

```raku
method create(
    $table
) returns Str
```

Render CREATE TABLE from a captured table, including supported primary keys, unique groups, references and checks.

### method diff

```raku
method diff(
    Red::Migration::Snapshot $old,
    Red::Migration::Snapshot $new,
    Bool :$allow-destructive = Bool::False
) returns Array
```

Return ordered SQL statements that transform one snapshot into another. Create referenced tables first, require explicit destructive permission for removals, and reject unsupported conversions or constraint alterations.

