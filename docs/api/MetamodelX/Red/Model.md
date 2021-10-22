MetamodelX::Red::Model
----------------------

### method column-names

```raku
method column-names(
    |
) returns Mu
```

Returns a list of columns names.of the model.

### method constraints

```raku
method constraints(
    |
) returns Mu
```

Returns a hash of model constraints classified by type.

### method references

```raku
method references(
    |
) returns Mu
```

Returns a hash of foreign keys of the model.

### method table

```raku
method table(
    Mu \type
) returns Mu
```

Returns the table name for the model.

### method as

```raku
method as(
    Mu \type
) returns Mu
```

Returns the table alias

### method orig

```raku
method orig(
    Mu \type
) returns Mu
```

Returns the original model

### method rs-class-name

```raku
method rs-class-name(
    Mu \type
) returns Mu
```

Returns the name of the ResultSeq class

### method columns

```raku
method columns(
    |
) returns Mu
```

Returns a list of columns

### method migration-hash

```raku
method migration-hash(
    \model
) returns Hash(Any)
```

Returns a hash with the migration hash

### method id-values

```raku
method id-values(
    Red::Model:D $model
) returns Mu
```

Returns a liast of id values

### method default-nullable

```raku
method default-nullable(
    |
) returns Mu
```

Check if the model is nullable by default.

### method unique-constraints

```raku
method unique-constraints(
    \model
) returns Mu
```

Returns all columns with the unique counstraint

### method attr-to-column

```raku
method attr-to-column(
    |
) returns Mu
```

A map from attr to column

### method compose

```raku
method compose(
    Mu \type
) returns Mu
```

Compose

### method add-reference

```raku
method add-reference(
    $name,
    Red::Column $col
) returns Mu
```

Creates a new reference (foreign key).

### method add-unique-constraint

```raku
method add-unique-constraint(
    Mu:U \type,
    &columns
) returns Mu
```

Creates a new unique constraint.

### multi method add-pk-constraint

```raku
multi method add-pk-constraint(
    Mu:U \type,
    &columns
) returns Mu
```

Creates a new primary key constraint.

### multi method add-pk-constraint

```raku
multi method add-pk-constraint(
    Mu:U \type,
    @columns
) returns Mu
```

Creates the primary key constraint.

### method add-column

```raku
method add-column(
    ::T Red::Model:U \type,
    Red::Attr::Column $attr
) returns Mu
```

Creates a new column and adds it to the model.

### multi method rs

```raku
multi method rs(
    Mu:U $
) returns Red::ResultSeq
```

Returns the ResultSeq

### multi method all

```raku
multi method all(
    $obj
) returns Red::ResultSeq
```

Alias for C<.rs()>

### method temp

```raku
method temp(
    |
) returns Mu
```

Sets model as a temporary table

### multi method create-table

```raku
multi method create-table(
    \model,
    Bool :unless-exists(:$if-not-exists) where { ... },
    *%pars
) returns Mu
```

Creates table unless table already exists

### multi method create-table

```raku
multi method create-table(
    \model,
    :$with where { ... },
    :if-not-exists($unless-exists) where { ... }
) returns Mu
```

Creates table

### method apply-row-phasers

```raku
method apply-row-phasers(
    $obj,
    Mu:U $phase
) returns Mu
```

Applies phasers

### multi method save

```raku
multi method save(
    $obj,
    Bool :$insert! where { ... },
    Bool :$from-create,
    :$with where { ... }
) returns Mu
```

Saves that object on database (create a new row)

### multi method save

```raku
multi method save(
    $obj,
    Bool :$update! where { ... },
    :$with where { ... }
) returns Mu
```

Saves that object on database (update the row)

### multi method save

```raku
multi method save(
    $obj,
    :$with where { ... }
) returns Mu
```

Generic save, calls C<.^save: :insert> if C<.^is-on-db> or C<.^save: :update> otherwise

### multi method delete

```raku
multi method delete(
    \model,
    :$with where { ... }
) returns Mu
```

Deletes row from database

### multi method load

```raku
multi method load(
    Red::Model:U \model,
    |ids
) returns Mu
```

Loads object from the DB

### multi method new-with-id

```raku
multi method new-with-id(
    Red::Model:U \model,
    %ids,
    :$with where { ... }
) returns Mu
```

Creates a new object setting ids with this values

### multi method new-with-id

```raku
multi method new-with-id(
    Red::Model:U \model,
    |ids
) returns Mu
```

Creates a new object setting the id

### multi method search

```raku
multi method search(
    Red::Model:U \model,
    &filter,
    :$with where { ... }
) returns Mu
```

Receives a `Block` of code and returns a `ResultSeq` using the `Block`'s return as filter

### multi method search

```raku
multi method search(
    Red::Model:U \model,
    Red::AST $filter,
    :$with where { ... }
) returns Mu
```

Receives a `AST` of code and returns a `ResultSeq` using that `AST` as filter

### multi method search

```raku
multi method search(
    Red::Model:U \model,
    *%filter,
    :$with where { ... }
) returns Mu
```

Receives a hash of `AST`s of code and returns a `ResultSeq` using that `AST`s as filter

### multi method find

```raku
multi method find(
    |c
) returns Mu
```

Finds a specific row

