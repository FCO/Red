### multi sub schema

```raku
multi sub schema() returns Mu
```

Build a schema from the configured models without opening the configured database.

### method plan

```raku
method plan(
    :$where,
    Bool :$allow-destructive = Bool::True
) returns Array
```

Return development DDL without executing it.

### method update

```raku
method update(
    :$where,
    Bool :$allow-destructive = Bool::False
) returns Mu
```

Synchronize selected models without creating versioned migrations.

