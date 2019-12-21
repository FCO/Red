Red::Column
-----------

class Red::Column
-----------------

Represents a database column

class Red::Column::ReferencesProxy
----------------------------------

Subclass used to lazy evaluation of parameter types

### method comment

```perl6
method comment() returns Mu
```

Returns the class that column is part of.

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

### method alias

```perl6
method alias(
    Str $name
) returns Mu
```

Returns an alias of that column

