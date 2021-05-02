MetamodelX::Red::Describable
----------------------------

### method describe

```raku
method describe(
    \model
) returns Red::Cli::Table
```

Returns an object of type `Red::Cli::Table` that represents a database table of the caller.

### method diff-to-db

```raku
method diff-to-db(
    \model
) returns Mu
```

Returns the difference to transform this model to the database version.

### method diff-from-db

```raku
method diff-from-db(
    \model
) returns Mu
```

Returns the difference to transform the DB table into this model.

### method diff

```raku
method diff(
    \model,
    \other-model
) returns Mu
```

Returns the difference between two models.

