### method column-names

```perl6
method column-names(
    |
) returns Mu
```

Returns a list of columns names.of the model.

### method constraints

```perl6
method constraints(
    |
) returns Mu
```

Returns a hash of model constraints classified by type.

### method references

```perl6
method references(
    |
) returns Mu
```

Returns a hash of foreign keys of the model.

### method table

```perl6
method table(
    Mu \type
) returns Mu
```

Returns the table name for the model.

### method as

```perl6
method as(
    Mu \type
) returns Mu
```

Returns the table alias

### method orig

```perl6
method orig(
    Mu \type
) returns Mu
```

Returns the original model

### method rs-class-name

```perl6
method rs-class-name(
    Mu \type
) returns Mu
```

Returns the name of the ResultSeq class

### method columns

```perl6
method columns(
    |
) returns Mu
```

Returns a list of columns

### method migration-hash

```perl6
method migration-hash(
    \model
) returns Hash(Any)
```

Returns a hash with the migration hash

### method id-values

```perl6
method id-values(
    Red::Model:D $model
) returns Mu
```

Returns a liast of id values

### method default-nullable

```perl6
method default-nullable(
    |
) returns Mu
```

Check if the model is nullable by default.

### method unique-constraints

```perl6
method unique-constraints(
    \model
) returns Mu
```

Returns all columns with the unique counstraint

### method attr-to-column

```perl6
method attr-to-column(
    |
) returns Mu
```

A map from attr to column

### method compose

```perl6
method compose(
    Mu \type
) returns Mu
```

Compose

### method add-reference

```perl6
method add-reference(
    $name,
    Red::Column $col
) returns Mu
```

Creates a new reference (foreign key).

### method add-unique-constraint

```perl6
method add-unique-constraint(
    Mu:U \type,
    &columns
) returns Mu
```

Creates a new unique constraint.

### multi method add-pk-constraint

```perl6
multi method add-pk-constraint(
    Mu:U \type,
    &columns
) returns Mu
```

Creates a new primary key constraint.

### multi method add-pk-constraint

```perl6
multi method add-pk-constraint(
    Mu:U \type,
    @columns
) returns Mu
```

Creates the primary key constraint.

### method alias

```perl6
method alias(
    Red::Model:U \type,
    Str $name = { ... }
) returns Mu
```

Creates a new alias for the model.

### method add-column

```perl6
method add-column(
    ::T Red::Model:U \type,
    Red::Attr::Column $attr
) returns Mu
```

Creates a new column and adds it to the model.

### method rs

```perl6
method rs(
    $
) returns Red::ResultSeq
```

Returns the ResultSeq

### method all

```perl6
method all(
    $obj
) returns Red::ResultSeq
```

Alias for C<.rs()>

### method temp

```perl6
method temp(
    |
) returns Mu
```

Sets model as a temporary table

### multi method create-table

```perl6
multi method create-table(
    \model,
    Bool :unless-exists(:$if-not-exists) where { ... }
) returns Mu
```

Creates table unless table already exists

### multi method create-table

```perl6
multi method create-table(
    \model
) returns Mu
```

Creates table

### method apply-row-phasers

```perl6
method apply-row-phasers(
    $obj,
    Mu:U $phase
) returns Mu
```

Applies phasers

### multi method save

```perl6
multi method save(
    $obj,
    Bool :$insert! where { ... },
    Bool :$from-create
) returns Mu
```

Saves that object on database (create a new row)

### multi method save

```perl6
multi method save(
    $obj,
    Bool :$update! where { ... }
) returns Mu
```

Saves that object on database (update the row)

### multi method save

```perl6
multi method save(
    $obj
) returns Mu
```

Generic save, calls C<.^save: :insert> if C<.^is-on-db> or C<.^save: :update> otherwise

### method create

```perl6
method create(
    \model,
    *%orig-pars
) returns Mu
```

Creates a new object and saves it on DB It accepts a list os pairs (the same as C<.new>) And Lists and/or Hashes for relationships

### method delete

```perl6
method delete(
    \model
) returns Mu
```

Deletes row from database

### method load

```perl6
method load(
    Red::Model:U \model,
    |ids is raw
) returns Mu
```

Loads object from the DB

### multi method new-with-id

```perl6
multi method new-with-id(
    Red::Model:U \model,
    %ids
) returns Mu
```

Creates a new object setting ids with this values

### multi method new-with-id

```perl6
multi method new-with-id(
    Red::Model:U \model,
    |ids is raw
) returns Mu
```

Creates a new object setting the id

### multi method search

```perl6
multi method search(
    Red::Model:U \model,
    &filter
) returns Mu
```

Receives a `Block` of code and returns a `ResultSeq` using the `Block`'s return as filter

### multi method search

```perl6
multi method search(
    Red::Model:U \model,
    Red::AST $filter
) returns Mu
```

Receives a `AST` of code and returns a `ResultSeq` using that `AST` as filter

### multi method search

```perl6
multi method search(
    Red::Model:U \model,
    *%filter
) returns Mu
```

Receives a hash of `AST`s of code and returns a `ResultSeq` using that `AST`s as filter

### method find

```perl6
method find(
    |c is raw
) returns Mu
```

Finds a specific row

