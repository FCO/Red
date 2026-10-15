class Red::Projection
---------------------

Describes the shape of one projected row independently of its SQL fields.

### method literal-inflator

```raku
method literal-inflator(
    Mu:U $type
) returns Callable:D
```

Parameter-only relations can be returned as strings by database drivers.

### method json-presence

```raku
method json-presence(
    Red::AST:D $value
) returns Red::AST:D
```

Tracks whether a JSON value denotes a present value rather than an absent path.

### method safe-to-repeat

```raku
method safe-to-repeat(
    $value
) returns Bool
```

Whether an expression can be substituted into another SQL clause.

### method rebind-leaves

```raku
method rebind-leaves(
    @expressions,
    Int $index is rw
) returns Red::Projection:D
```

Internal extension point for rebinding a shape to exported SQL fields.

### method with-undefined-types

```raku
method with-undefined-types(
    @types,
    Int $index is rw
) returns Red::Projection:D
```

Preserve the type objects supplied as nullable literal values.

### method materialize

```raku
method materialize(
    @values,
    Int $index is rw
) returns Mu
```

Internal extension point for reconstructing one result element.

