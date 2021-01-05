Red::Traits
-----------

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$temp!
) returns Empty
```

This trait marks the corresponding table of the model as TEMPORARY (so it only exists for the time of Red being connected to the database).

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
    Bool :$unique! where { ... }
) returns Empty
```

This trait marks an attribute (column) as UNIQUE.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$id! where { ... }
) returns Empty
```

This trait marks an attribute (column) as SQL PRIMARY KEY.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$serial! where { ... }
) returns Empty
```

This trait marks an attribute (column) as SQL PRIMARY KEY with SERIAL data type, which means it auto-increments on each insertion.

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
    Attribute $attr,
    :$referencing! (&referencing, Str :$model!, Str :$require = { ... }, Bool :$nullable = Bool::True)
) returns Empty
```

Trait that defines a reference

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (Str :$model!, Str :$column!, Str :$require = { ... }, Bool :$nullable = Bool::True)
) returns Empty
```

Trait that defines a reference

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Str :$table! is copy where { ... }
) returns Empty
```

This trait allows setting a custom name for a table corresponding to a model. For example, `model MyModel is table<custom_table_name> {}` will use `custom_table_name` as the name of the underlying database table.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :@relationship! where { ... }
) returns Empty
```

Trait that defines a relationship

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (&relationship, Str :$model, Str :$require = { ... }, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

Trait that defines a relationship

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (Str :$column!, Str :$model!, Str :$require = { ... }, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

Trait that defines a relationship

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Callable :$relationship! (@relationship where { ... }, Str :$model!, Str :$require = { ... }, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

Trait that defines a relationship

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$before-create!
) returns Empty
```

Trait to define a phaser to run before create a new record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$after-create!
) returns Empty
```

Trait to define a phaser to run after create a new record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$before-update!
) returns Empty
```

Trait to define a phaser to run before update a record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$after-update!
) returns Empty
```

Trait to define a phaser to run after update record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$before-delete!
) returns Empty
```

Trait to define a phaser to run before delete a record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$after-delete!
) returns Empty
```

Trait to define a phaser to run after delete a record

