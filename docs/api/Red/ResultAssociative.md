Red::ResultAssociative
----------------------



Lazy Associative class from Red queries (.classify)

### method map

```raku
method map(
    &projection,
    :$red-ast
) returns Mu
```

Project group keys and aggregates in SQL without enumerating the groups.

### method of

```raku
method of() returns Mu
```

type of the value

### method key-of

```raku
method key-of() returns Mu
```

type of the key

### method keys

```raku
method keys() returns Mu
```

return a list of keys run a SQL query to get it

### method elems

```raku
method elems() returns Mu
```

Run query to get the number of elements

### method AT-KEY

```raku
method AT-KEY(
    $key
) returns Mu
```

return a ResultSeq for the given key

### method Bag

```raku
method Bag() returns Mu
```

Run query to create a Bag

### method Set

```raku
method Set() returns Mu
```

Run query to create a Set

