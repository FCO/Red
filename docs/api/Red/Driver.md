Red::Driver
-----------



Base role for a Red::Driver::*

### has Supply $.events

Supply of events of that driver

### method begin

```perl6
method begin() returns Mu
```

Begin transaction

### method commit

```perl6
method commit() returns Mu
```

Commit transaction

### method rollback

```perl6
method rollback() returns Mu
```

Rollback transaction

### method auto-register

```perl6
method auto-register(
    |
) returns Mu
```

Self-register its events on Red.events

### method emit

```perl6
method emit(
    $data?
) returns Mu
```

Emit events

### method emit

```perl6
method emit(
    Red::Event $event
) returns Mu
```

Emit events

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
    "varchar"
) returns "varchar(255)"
```

Maps types

### method type-by-name

```perl6
method type-by-name(
    "string"
) returns "text"
```

Maps types

### method type-by-name

```perl6
method type-by-name(
    "int"
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

### method inflate

```perl6
method inflate(
    $value,
    :$to
) returns Mu
```

Default inflator

### method execute

```perl6
method execute(
    $query,
    *@bind
) returns Mu
```

Execute query

### method optimize

```perl6
method optimize(
    Red::AST $in
) returns Red::AST
```

Optimize AST

