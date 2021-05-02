Red::Column
-----------

class Red::Column
-----------------

Represents a database column

### method migration-hash

```raku
method migration-hash() returns Hash(Any)
```

Returns a Hash that represents the column for migration purposes

class Red::Column::ReferencesProxy
----------------------------------

Subclass used to lazy evaluation of parameter types

### method comment

```raku
method comment() returns Mu
```

Returns the class that column is part of. Method that returns the comment for the column

### method references

```raku
method references() returns Callable
```

Returns a function that will return a column that is referenced by this column

### method ref

```raku
method ref(
    $model = Code.new
) returns Mu
```

Returns the column that is referenced by this one.

### method returns

```raku
method returns() returns Mu
```

Required by the Red::AST role

### method alias

```raku
method alias(
    Str $name
) returns Mu
```

Returns an alias of that column

### method as

```raku
method as(
    Str $name,
    :$nullable = Bool::True
) returns Mu
```

Returns a clone using a different name

### method defined

```raku
method defined() returns Mu
```

Do not test definedness, but returns a new Red::AST::IsDefined. It's used to test `IS NULL` on the given column. It's also used by any construction that naturally uses `.defined`.

