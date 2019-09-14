### method describe

```perl6
method describe(
    \model
) returns Red::Cli::Table
```

Returns an object of type `Red::Cli::Table` that represents a database table of the caller.

### method diff-to-db

```perl6
method diff-to-db(
    \model
) returns Red::Cli::Table
```

Returns the difference to transform this model to the database version.

### method diff-from-db

```perl6
method diff-from-db(
    \model
) returns Red::Cli::Table
```

Returns the difference to transform the DB table into this model.

### method diff

```perl6
method diff(
    \model,
    \other-model
) returns Red::Cli::Table
```

Returns the difference between two models.

