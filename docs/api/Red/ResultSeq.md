### method Seq

```perl6
method Seq() returns Mu
```

Returns a Seq with the result of the SQL query

### method grep

```perl6
method grep(
    &filter
) returns Mu
```

Adds a new filter on the query (does not run the query)

### method first

```perl6
method first(
    &filter
) returns Mu
```

Changes the query to return only the first row that matches the condition and run it (.grep(...).head)

### method map

```perl6
method map(
    &filter
) returns Mu
```

Change what will be returned (does not run the query)

### method sort

```perl6
method sort(
    &order
) returns Mu
```

Defines the order of the query (does not run the query)

### method pick

```perl6
method pick(
    Whatever $
) returns Mu
```

Sets the query to return the rows in a randomic order (does not run the query)

### method classify

```perl6
method classify(
    &func,
    :&as = { ... }
) returns Mu
```

Returns a ResultAssociative classified by the passed code (does not run the query)

### method head

```perl6
method head() returns Mu
```

Gets the first row returned by the query (run the query)

### method from

```perl6
method from(
    Int:D $num where { ... }
) returns Mu
```

Sets the ofset of the query

### method elems

```perl6
method elems() returns Int(Any)
```

Returns the number of rows returned by the query (runs the query)

### method Bool

```perl6
method Bool() returns Bool(Any)
```

Returns True if there are lines returned by the query False otherwise (runs the query)

### method batch

```perl6
method batch(
    Int $size
) returns Mu
```

Returns a ResultSeqSeq containing ResultSeq that will return ResultSeqs with $size rows each (do not run the query)

### method create

```perl6
method create(
    *%pars
) returns Mu
```

Creates a new element of that set

### method delete

```perl6
method delete() returns Mu
```

Deletes every row on that ResultSeq

### method save

```perl6
method save() returns Mu
```

Saves any change on any element of that ResultSet

### method union

```perl6
method union(
    $other
) returns Mu
```

unifies 2 ResultSeqs

### method intersect

```perl6
method intersect(
    $other
) returns Mu
```

intersects 2 ResultSeqs

### method minus

```perl6
method minus(
    $other
) returns Mu
```

Removes 1 ResultSeq elements from other ResultSeq

