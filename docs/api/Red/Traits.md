Red::Traits
-----------

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$temp!
) returns Empty
```

This trait marks the corresponding table of the model as TEMPORARY (so it only exists for the time of Red being connected to the database)

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$nullable!
) returns Empty
```

This trait configures all model attributes (columns) to be NULLABLE by default, when used as `is nullable`. Without this trait applied, default for every attribute (column) is NOT NULL, though it can be stated explicitly with writing `is !nullable` for the model. Defaults can be overridden using `is nullable` or `is !nullable` for the attribute (column) itself.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$id! where { ... }
) returns Empty
```

This trait marks an attribute (column) as SQL PRIMARY KEY

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$serial! where { ... }
) returns Empty
```

This trait marks an attribute (column) as SQL PRIMARY KEY with SERIAL data type, which means it auto-increments on each insertion

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :%column!
) returns Empty
```

A generic trait used for customizing a column. It accepts a hash of Bool keys. Possible values include: * id - marks a column PRIMARY KEY * auto-increment - marks a column AUTO INCREMENT * nullable - marks a column as NULLABLE * TBD

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Str :$table! where { ... }
) returns Empty
```

This trait allows setting a custom name for a table corresponding to a model. For example, `model MyModel is table<custom_table_name> {}` will use `custom_table_name` as the name of the underlying database table

