Red::Driver
-----------



Base role for a Red::Driver::*

### has Supply $.events

Supply of events of that driver

### method begin

```raku
method begin() returns Mu
```

Begin transaction

### method commit

```raku
method commit() returns Mu
```

Commit transaction

### method rollback

```raku
method rollback() returns Mu
```

Rollback transaction

### method auto-register

```raku
method auto-register(
    |
) returns Mu
```

Self-register its events on Red.events

### method emit

```raku
method emit(
    $data?
) returns Mu
```

Emit events

### method emit

```raku
method emit(
    Red::Event $event
) returns Mu
```

Emit events

### method prepare

```raku
method prepare(
    Red::AST $query
) returns Mu
```

Prepares a DB statement

### method is-valid-table-name

```raku
method is-valid-table-name(
    Str $
) returns Bool
```

Checks if a name is a valid table name

### method type-by-name

```raku
method type-by-name(
    "varchar"
) returns "varchar(255)"
```

Maps types

### method type-by-name

```raku
method type-by-name(
    "string"
) returns "text"
```

Maps types

### method type-by-name

```raku
method type-by-name(
    "int"
) returns "integer"
```

Maps types

### method map-exception

```raku
method map-exception(
    $orig-exception
) returns Mu
```

Maps exception

### method inflate

```raku
method inflate(
    $value,
    :$to
) returns Mu
```

Default inflator

### method execute

```raku
method execute(
    $query,
    *@bind
) returns Mu
```

Execute query

### method optimize

```raku
method optimize(
    Red::AST $in
) returns Red::AST
```

Optimize AST

