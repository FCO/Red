MetamodelX::Red::Dirtable
-------------------------

### sub deep-clone

```raku
sub deep-clone(
    \v
) returns Mu
```

Deep-clones a collection, preserving container types (Array[Str], Hash[Int]...). Immutable containers (List, Map, Set, Bag, Mix) and non-collection values (scalars, type objects, Dates, Models) are returned as-is — safe because they cannot be mutated in place.

### sub collection-column

```raku
sub collection-column(
    Red::Attr::Column \col
) returns Bool
```

True when the column can hold a collection-typed value. Wide on purpose: `@.`/`%.` columns declare Positional/Associative constraints, and Json columns declare Json. Immutable containers (List, Map, Set, Bag, Mix) can flow through, but `deep-clone` returns them as-is — they cannot be mutated in place, so a live reference is a safe snapshot for them.

### method set-dirty

```raku
method set-dirty(
    \obj,
    Red::Attr::Column $attr
) returns Mu
```

Accepts a Set of attributes of model and enables dirtiness flag for them, which means that the values were changed and need a database sync.

### method is-dirty

```raku
method is-dirty(
    Any:D \obj
) returns Bool
```

Returns `True` if any of the object attributes were changed from original database record values.

### method dirty-columns

```raku
method dirty-columns(
    Any:D \obj
) returns Mu
```

Returns dirty columns of the object.

### method clean-up

```raku
method clean-up(
    Any:D \obj
) returns Mu
```

Erases dirty status from all model's attributes, but does not (!) revert their values to original ones.

### method sync-collection-snapshots

```raku
method sync-collection-snapshots(
    \obj
) returns Mu
```

Captures a deep-clone snapshot of every collection column's current value.

### method sync-collection-dirty

```raku
method sync-collection-dirty(
    \obj
) returns Mu
```

Compares current collection values against snapshots and marks divergent columns dirty, refreshing their snapshots.

