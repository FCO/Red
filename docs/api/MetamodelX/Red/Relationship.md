### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    Str :$column!,
    Str :$model!,
    Str :$require = { ... }
) returns Mu
```

Adds a new relationship

### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    &reference,
    Str :$model,
    Str :$require = { ... }
) returns Mu
```

Adds a new relationship

### method add-relationship

```perl6
method add-relationship(
    Mu:U $self,
    Attribute $attr,
    &ref1,
    &ref2,
    Str :$model,
    Str :$require = { ... }
) returns Mu
```

Adds a new relationship

### method add-relationship

```perl6
method add-relationship(
    ::Type Mu:U $self,
    Red::Attr::Relationship $attr
) returns Mu
```

Adds a new relationship

