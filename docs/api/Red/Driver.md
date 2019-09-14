### method prepare

```perl6
method prepare(
    Red::AST $query
) returns Mu
```

Prepares a DB statement

### method is-valid-table-name

```perl6
method is-valid-table-name(
    Str $
) returns Bool
```

Checks if a name is a valid table name

### method type-by-name

```perl6
method type-by-name(
    Str $ where { ... }
) returns "text"
```

Maps types

### method type-by-name

```perl6
method type-by-name(
    Str $ where { ... }
) returns "integer"
```

Maps types

### method map-exception

```perl6
method map-exception(
    $orig-exception
) returns Mu
```

Maps exception

### method optimize

```perl6
method optimize(
    Red::AST $in
) returns Red::AST
```

Optimize AST

