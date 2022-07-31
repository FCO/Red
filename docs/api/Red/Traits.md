Red::Traits
-----------

### is temp

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$temp!
) returns Empty
```

This trait marks the corresponding table of the model as TEMPORARY (so it only exists for the time of Red being connected to the database).

### is rs-class

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Mu:U $model,
    Str:D :$rs-class!
) returns Empty
```

This trait defines the name of the class to be used as ResultSet to this model.

### is rs-class

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Mu:U $model,
    Mu:U :$rs-class!
) returns Empty
```

This trait defines the class to be used as ResultSet to this model.

### is nullable

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Mu:U $model,
    Bool :$nullable!
) returns Empty
```

This trait configures all model attributes (columns) to be NULLABLE by default, when used as `is nullable`. Without this trait applied, default for every attribute (column) is NOT NULL, though it can be stated explicitly with writing `is !nullable` for the model. Defaults can be overridden using `is nullable` or `is !nullable` for the attribute (column) itself.

### is column

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$column!
) returns Empty
```

Defines the attribute as a column without any custom configuration.

### is column

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    Str :$column!
) returns Empty
```

Defines the attribute as a column receiving a string to be used as the column name.

### is unique

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$unique! where { ... }
) returns Empty
```

This trait marks an attribute (column) as UNIQUE.

### is unique

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$unique!
) returns Empty
```

This trait marks an attribute (column) as UNIQUE receiving data to ve used on column definition.

### is id

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$id! where { ... }
) returns Empty
```

This trait marks an attribute (column) as SQL PRIMARY KEY.

### is serial

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    Bool :$serial! where { ... }
) returns Empty
```

This trait marks an attribute (column) as SQL PRIMARY KEY with SERIAL data type, which means it auto-increments on each insertion.

### is column

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :%column!
) returns Empty
```

A generic trait used for customizing a column. It accepts a hash of Bool keys. Possible values include: * id - marks a column PRIMARY KEY * auto-increment - marks a column AUTO INCREMENT * nullable - marks a column as NULLABLE * TBD

### is referencing

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (&referencing, Str :$model!, Str :$require = Code.new, Bool :$nullable = Bool::True, *%rest)
) returns Empty
```

Trait that defines a reference receiving a code block, a model name, optional require string and nullable.

### is referencing

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (Str :$model!, Str :$column!, Str :$require = Code.new, Bool :$nullable = Bool::True, *%rest)
) returns Empty
```

Trait that defines a reference receiving a model name, a column name, and optional require string and nulabble.

### is referencing

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (&referencing, Mu:U :$model!, Bool :$nullable = Bool::True, *%rest)
) returns Empty
```

Trait that defines a reference receiving a code block, a model type object and an optional nullable.

### is referencing

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$referencing! (Mu:U :$model!, Str :$column!, Bool :$nullable = Bool::True, *%rest)
) returns Empty
```

Trait that defines a reference receiving a model type object, a column name, and optional nulabble.

### is table

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Mu:U $model,
    Str :$table! is copy where { ... }
) returns Empty
```

This trait allows setting a custom name for a table corresponding to a model. For example, `model MyModel is table<custom_table_name> {}` will use `custom_table_name` as the name of the underlying database table.

### is relationship

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :&relationship!
) returns Empty
```

Trait that defines a relationship receiving a code block.

### is relationship

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :@relationship! where { ... }
) returns Empty
```

DEPRECATED: Trait that defines a relationship receiving 2 code blocks.

### is relationship

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (&relationship, Str :$model, Str :$require = Code.new, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

Trait that defines a relationship receiving a code block, a model name, and opitionaly require string, optional, no-prefetch and has-one.

### is relationship

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (&relationship, Mu:U :$model!, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

Trait that defines a relationship receiving a code block, a model type object, and opitionaly require string, optional, no-prefetch and has-one.

### is relationship

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Attribute $attr,
    :$relationship! (Str :$column!, Str :$model!, Str :$require = Code.new, Bool :$optional, Bool :$no-prefetch, Bool :$has-one)
) returns Empty
```

Trait that defines a relationship receiving a column name, a model name and opitionaly a require, optional, no-prefetch and has-one.

### is before-create

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $m,
    :$before-create!
) returns Empty
```

Trait to define a phaser to run before create a new record

### is after-create

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $m,
    :$after-create!
) returns Empty
```

Trait to define a phaser to run after create a new record

### is before-update

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $m,
    :$before-update!
) returns Empty
```

Trait to define a phaser to run before update a record

### is after-update

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $m,
    :$after-update!
) returns Empty
```

Trait to define a phaser to run after update record

### is before-delete

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $m,
    :$before-delete!
) returns Empty
```

Trait to define a phaser to run before delete a record

### is after-delete

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $m,
    :$after-delete!
) returns Empty
```

Trait to define a phaser to run after delete a record

head
====

is sub-module

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    $subset where { ... },
    Bool :$sub-model
) returns Mu
```

Trait to transform subset into sub-model

