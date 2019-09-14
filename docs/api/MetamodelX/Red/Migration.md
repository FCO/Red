### method migration

```perl6
method migration(
    \model,
    &migr
) returns Mu
```

Creates a new migration for the model.

### method migrate

```perl6
method migrate(
    \model,
    Red::Model:U :$from
) returns Mu
```

Executes migrations.

### method dump-migrations

```perl6
method dump-migrations(
    |
) returns Mu
```

Prints the migrations.

