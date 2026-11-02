Red::Migration::Snapshot
------------------------

### method source

```raku
method source() returns Str
```

Serialize the schema deterministically as typed config, table and column builders. Preserve historical Raku types, SQL mappings, key information and portable descriptors without importing application models.

### method load

```raku
method load(
    IO(Any) $path
) returns Red::Migration::Snapshot
```

Evaluate a trusted schema artifact and reconstruct a snapshot. Accept both current configuration builders and legacy table collections.

