MetamodelX::Red::Migration
--------------------------

### method migration

```raku
method migration(
    \model,
    &migr
) returns Mu
```

Creates a new migration for the model.

### method migrate

```raku
method migrate(
    \model,
    Red::Model:U :$from
) returns Mu
```

Executes migrations.

### method dump-migrations

```raku
method dump-migrations(
    |
) returns Mu
```

Prints the migrations.

