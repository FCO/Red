### method describe

```perl6
method describe(
    \model
) returns Red::Cli::Table
```

Return a `Red::Cli::Table` describing the table

### method diff-to-db

```perl6
method diff-to-db(
    \model
) returns Mu
```

Returns the difference to transform this model to the database version

### method diff-from-db

```perl6
method diff-from-db(
    \model
) returns Mu
```

Returns the difference to transform the DB table into this model

### method diff

```perl6
method diff(
    \model,
    \other-model
) returns Mu
```

Returns the difference between two models

