MetamodelX::Red::Migration
--------------------------

### method migration

```raku
method migration(
    \model,
    &migr
) returns Mu
```

Register a symbolic transformation block for this model only. Registration does not execute database statements; migrate collects the assignments produced by the registered blocks.

### method migrate

```raku
method migrate(
    \model,
    Red::Model:U :$from
) returns Mu
```

Evaluate registered blocks against column proxies from the supplied historical model and return their assignments. Each invocation collects fresh results without sharing other models' blocks. This legacy API is distinct from the versioned migration.raku compiler.

### method dump-migrations

```raku
method dump-migrations(
    \model
) returns Mu
```

Print the assignments most recently collected for this model. Does not apply or persist them.

