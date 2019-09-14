### method migration

```perl6
method migration(
    \model,
    &migr
) returns Mu
```

Creates a new migration

### method migrate

```perl6
method migrate(
    \model,
    Red::Model:U :$from
) returns Mu
```

Runs migrations

### method dump-migrations

```perl6
method dump-migrations(
    |
) returns Mu
```

Prints the migrations

