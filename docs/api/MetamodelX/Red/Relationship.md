MetamodelX::Red::Relationship
-----------------------------

### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    &reference,
    Red::Model :$model-type!,
    Bool :$optional,
    Bool :$no-prefetch,
    Bool :$has-one
) returns Mu
```

Adds a new relationship by reference.

### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    Str :$column!,
    Str :$model!,
    Str :$require = { ... },
    Bool :$optional,
    Bool :$no-prefetch,
    Bool :$has-one
) returns Mu
```

Adds a new relationship by column.

### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    &reference,
    Str :$model,
    Str :$require = { ... },
    Bool :$optional,
    Bool :$no-prefetch,
    Bool :$has-one
) returns Mu
```

Adds a new relationship by reference.

### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    &ref1,
    &ref2,
    Str :$model,
    Str :$require = { ... },
    Bool :$optional,
    Bool :$no-prefetch,
    Bool :$has-one
) returns Mu
```

Adds a new relationship by two references.

### method add-relationship

```perl6
method add-relationship(
    ::Type Mu:U $self,
    Red::Attr::Relationship $attr
) returns Mu
```

Adds a new relationship using an attribute of type `Red::Attr::Relationship`.

