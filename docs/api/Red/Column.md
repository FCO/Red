Red::Column
-----------

class Red::Column
-----------------

Represents a database column

### method migration-hash

```perl6
method migration-hash() returns Hash(Any)
```

Returns a Hash that represents the column for migration purposes

class Red::Column::ReferencesProxy
----------------------------------

Subclass used to lazy evaluation of parameter types

### method comment

```perl6
method comment() returns Mu
```

Returns the class that column is part of. Method that returns the comment for the column

### method references

```perl6
method references() returns Callable
```

Returns a function that will return a column that is referenced by this column

### method ref

```perl6
method ref(
    $model = Nil
) returns Mu
```

Returns the column that is referenced by this one.

### method returns

```perl6
method returns() returns Mu
```

Required by the Red::AST role

### method alias

```perl6
method alias(
    Str $name
) returns Mu
```

Returns an alias of that column

### method as

```perl6
method as(
    Str $name,
    :$nullable = Bool::True
) returns Mu
```

Returns a clone using a different name

### method defined

```perl6
method defined() returns Mu
```

Do not test definedness, but returns a new Red::AST::IsDefined. It's used to test `IS NULL` on the given column. It's also used by any construction that naturally uses `.defined`.

