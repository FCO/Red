MetamodelX::Red::Id
-------------------

### method is-id

```raku
method is-id(
    $,
    Red::Attr::Column $attr
) returns Mu
```

Checks if the given attribute is a primary key of the model.

### method id

```raku
method id(
    Mu \type
) returns Mu
```

Gets a list of ids

### method general-ids

```raku
method general-ids(
    \model
) returns Mu
```

Returns a list of attributes that are either primary keys or marked as unique.

### method populate-ids

```raku
method populate-ids(
    Red::Model:D $model
) returns Mu
```

Sets ids

### method reset-id

```raku
method reset-id(
    Red::Model:D $model
) returns Mu
```

resets id

### method set-id

```raku
method set-id(
    Red::Model:D $model,
    %ids
) returns Hash(Any)
```

Sets ids

### method set-id

```raku
method set-id(
    Red::Model:D $model,
    $id where { ... }
) returns Hash(Any)
```

Sets id

### method id-map

```raku
method id-map(
    Red::Model $model,
    $id
) returns Hash(Any)
```

Returns a Hash with an id map

### method id-filter

```raku
method id-filter(
    Red::Model:D $model
) returns Mu
```

Returns a filter using the id

### method id-filter

```raku
method id-filter(
    Red::Model:U $model,
    $id
) returns Mu
```

Returns a filter using the id

### method id-filter

```raku
method id-filter(
    Red::Model:U $model,
    *%data
) returns Mu
```

Returns a filter using the id

