MetamodelX::Red::Id
-------------------

### method is-id

```perl6
method is-id(
    $,
    Red::Attr::Column $attr
) returns Mu
```

Checks if the given attribute is a primary key of the model.

### method id

```perl6
method id(
    Mu \type
) returns Mu
```

Gets a list of ids

### method general-ids

```perl6
method general-ids(
    \model
) returns Mu
```

Returns a list of attributes that are either primary keys or marked as unique.

### method populate-ids

```perl6
method populate-ids(
    Red::Model:D $model
) returns Mu
```

Sets ids

### method reset-id

```perl6
method reset-id(
    Red::Model:D $model
) returns Mu
```

resets id

### method set-id

```perl6
method set-id(
    Red::Model:D $model,
    %ids
) returns Hash(Any)
```

Sets ids

### method set-id

```perl6
method set-id(
    Red::Model:D $model,
    $id where { ... }
) returns Hash(Any)
```

Sets id

### method id-map

```perl6
method id-map(
    Red::Model $model,
    $id
) returns Hash(Any)
```

Returns a Hash with an id map

### method id-filter

```perl6
method id-filter(
    Red::Model:D $model
) returns Mu
```

Returns a filter using the id

### method id-filter

```perl6
method id-filter(
    Red::Model:U $model,
    $id
) returns Mu
```

Returns a filter using the id

### method id-filter

```perl6
method id-filter(
    Red::Model:U $model,
    *%data
) returns Mu
```

Returns a filter using the id

