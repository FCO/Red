### sub index-options

```raku
sub index-options(
    $value
) returns Hash
```

Normalize the value shared by the attribute trait and is column configuration.

### sub index-expression

```raku
sub index-expression(
    $value,
    Mu:U $model
) returns Red::AST
```

Lower an expression to DDL without modifying the AST used by queries.

### sub canonical-index-key

```raku
sub canonical-index-key(
    Str $sql
) returns Str
```

Compare catalog spelling without altering literals, grouping or identifier case.

### sub sql-index-keys

```raku
sub sql-index-keys(
    Str $sql
) returns Array
```

Read an index key list without splitting commas inside expressions or literals.

