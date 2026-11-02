Red::Migration::Logical
-----------------------

### sub logical-capture

```raku
sub logical-capture(
    @models,
    %snapshots,
    @drivers
) returns Red::Migration::Snapshot
```

Capture a portable model schema from concrete driver snapshots. Preserve Raku types, SQL type origins and mappings, plus descriptors needed to regenerate indexes and constraints.

### sub descriptor

```raku
sub descriptor(
    Str $source
) returns Mu
```

Reconstruct a trusted historical portable SQL descriptor without importing the current application model implementation.

### sub translate-logical

```raku
sub translate-logical(
    Red::Migration::Snapshot $logical,
    $backend,
    Str $dialect,
    %mappings = Code.new
) returns Red::Migration::Snapshot
```

Resolve a portable snapshot into a concrete driver schema. Apply configured type mappings and dialect-specific descriptors; reject explicit types without a mapping.

### sub schema-data

```raku
sub schema-data(
    Red::Migration::Snapshot $snapshot
) returns Hash
```

Convert a snapshot into canonical nested data for schema comparison and branch rebasing. Exclude model names from structural conflict detection.

### sub schema-from-data

```raku
sub schema-from-data(
    %data
) returns Red::Migration::Snapshot
```

Rebuild a logical snapshot from canonical schema data after changes have been merged or rebased.

### sub changes

```raku
sub changes(
    %before,
    %after,
    :@path = Code.new
) returns Array
```

Return deterministic path-based differences between canonical schemas, retaining old and new values so conflicts can be checked during rebasing.

### sub clone-data

```raku
sub clone-data(
    $value
) returns Mu
```

Recursively copy canonical schema collections before applying changes, leaving the original state unchanged.

### sub rebase

```raku
sub rebase(
    %state,
    @changes
) returns Hash
```

Apply recorded schema changes to an accumulated branch state. Accept already equivalent changes and reject paths whose original value no longer matches.

