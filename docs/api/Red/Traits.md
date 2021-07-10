Red::Traits
-----------

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$temp!
) returns Empty
```

is temp This trait marks the corresponding table of the model as TEMPORARY (so it only exists for the time of Red being connected to the database).

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Str:D :$rs-class!
) returns Empty
```

is rs-class This trait defines the name of the class to be used as ResultSet to this model.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Mu:U :$rs-class!
) returns Empty
```

is rs-class This trait defines the class to be used as ResultSet to this model.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$nullable!
) returns Empty
```

is nullable This trait configures all model attributes (columns) to be NULLABLE by default, when used as `is nullable`. Without this trait applied, default for every attribute (column) is NOT NULL, though it can be stated explicitly with writing `is !nullable` for the model. Defaults can be overridden using `is nullable` or `is !nullable` for the attribute (column) itself.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$column!
) returns Empty
```

is column Defines the attribute as a column without any custom configuration.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Str :$column!
) returns Empty
```

is column Defines the attribute as a column receiving a string to be used as the column name.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$unique! where { ... }
) returns Empty
```

is unique This trait marks an attribute (column) as UNIQUE.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$unique!
) returns Empty
```

is unique This trait marks an attribute (column) as UNIQUE receiving data to ve used on column definition.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$id! where { ... }
) returns Empty
```

is id This trait marks an attribute (column) as SQL PRIMARY KEY.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$serial! where { ... }
) returns Empty
```

is serial This trait marks an attribute (column) as SQL PRIMARY KEY with SERIAL data type, which means it auto-increments on each insertion.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :%column!
) returns Empty
```

is column A generic trait used for customizing a column. It accepts a hash of Bool keys. Possible values include: * id - marks a column PRIMARY KEY * auto-increment - marks a column AUTO INCREMENT * nullable - marks a column as NULLABLE * TBD

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (&referencing, Str :$model!, Str :$require = { ... }, Bool :$nullable = Bool::True)
) returns Empty
```

is referencing Trait that defines a reference receiving a code block, a model name, optional require string and nullable.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (Str :$model!, Str :$column!, Str :$require = { ... }, Bool :$nullable = Bool::True)
) returns Empty
```

is referencing Trait that defines a reference receiving a model name, a column name, and optional require string and nulabble.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (&referencing, Mu:U :$model!, Bool :$nullable = Bool::True)
) returns Empty
```

is referencing Trait that defines a reference receiving a code block, a model type object and an optional nullable.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (Mu:U :$model!, Str :$column!, Bool :$nullable = Bool::True)
) returns Empty
```

is referencing Trait that defines a reference receiving a model type object, a column name, and optional nulabble.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Mu:U $model,
    Str :$table! is copy where { ... }
) returns Empty
```

is table This trait allows setting a custom name for a table corresponding to a model. For example, `model MyModel is table<custom_table_name> {}` will use `custom_table_name` as the name of the underlying database table.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :&relationship!
) returns Empty
```

is relationship Trait that defines a relationship receiving a code block.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :@relationship! where { ... }
) returns Empty
```

is relationship DEPRECATED: Trait that defines a relationship receiving 2 code blocks.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (&relationship, Str :$model, Str :$require = { ... }, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

is relationship Trait that defines a relationship receiving a code block, a model name, and opitionaly require string, optional, no-prefetch and has-one.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (&relationship, Mu:U :$model!, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

is relationship Trait that defines a relationship receiving a code block, a model type object, and opitionaly require string, optional, no-prefetch and has-one.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (Str :$column!, Str :$model!, Str :$require = { ... }, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

is relationship Trait that defines a relationship receiving a column name, a model name and opitionaly a require, optional, no-prefetch and has-one.

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$before-create!
) returns Empty
```

is before-create Trait to define a phaser to run before create a new record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$after-create!
) returns Empty
```

is after-create Trait to define a phaser to run after create a new record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$before-update!
) returns Empty
```

is before-update Trait to define a phaser to run before update a record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$after-update!
) returns Empty
```

is after-update Trait to define a phaser to run after update record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$before-delete!
) returns Empty
```

is before-delete Trait to define a phaser to run before delete a record

### multi sub trait_mod:<is>

```perl6
multi sub trait_mod:<is>(
    Method $m,
    :$after-delete!
) returns Empty
```

is after-delete Trait to define a phaser to run after delete a record

