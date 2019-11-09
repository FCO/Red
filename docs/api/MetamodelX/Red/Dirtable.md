MetamodelX::Red::Dirtable
-------------------------

### method set-dirty

```perl6
method set-dirty(
    \obj,
    $attr
) returns Mu
```

Accepts a Set of attributes of model and enables dirtiness flag for them, which means that the values were changed and need a database sync.

### method is-dirty

```perl6
method is-dirty(
    Any:D \obj
) returns Bool
```

Returns `True` if any of the object attributes were changed from original database record values.

### method dirty-columns

```perl6
method dirty-columns(
    Any:D \obj
) returns Mu
```

Returns dirty columns of the object.

### method clean-up

```perl6
method clean-up(
    Any:D \obj
) returns Mu
```

Erases dirty status from all model's attributes, but does not (!) revert their values to original ones.

