Red::ResultSeq
--------------



Class that represents a Seq of query results

### sub comment-sql

```raku
sub comment-sql(
    :$meth-name,
    :$file,
    :$block,
    :$line
) returns Mu
```

Add a comment to SQL query

### method of

```raku
method of() returns Mu
```

The type of the ResultSeq

### method Seq

```raku
method Seq() returns Mu
```

Returns a Seq with the result of the SQL query

### method grep

```raku
method grep(
    &filter
) returns Mu
```

Adds a new filter on the query (does not run the query)

### method first

```raku
method first(
    &filter
) returns Red::Model
```

Changes the query to return only the first row that matches the condition and run it (.grep(...).head)

### method map

```raku
method map(
    &filter
) returns Mu
```

Change what will be returned (does not run the query)

### method sort

```raku
method sort(
    &order
) returns Red::ResultSeq
```

Defines the order of the query (does not run the query)

### method pick

```raku
method pick(
    Whatever $
) returns Red::ResultSeq
```

Sets the query to return the rows in a randomic order (does not run the query)

### method classify

```raku
method classify(
    &func,
    :&as = Code.new,
    :&reduce
) returns Red::ResultAssociative
```

Returns a ResultAssociative classified by the passed code (does not run the query)

### method Bag

```raku
method Bag() returns Mu
```

Runs a query to create a Bag

### method Set

```raku
method Set() returns Mu
```

Runs a query to create a Set

### method head

```raku
method head() returns Mu
```

Gets the first row returned by the query (run the query)

### method skip

```raku
method skip(
    Int:D $num where { ... }
) returns Red::ResultSeq
```

Skips the $num first items from ResultSeq (adds a limit on the SQL query)

### method elems

```raku
method elems() returns Int(Any)
```

Returns the number of rows returned by the query (runs the query)

### method Bool

```raku
method Bool() returns Bool
```

Returns True if there are lines returned by the query False otherwise (runs the query)

### method batch

```raku
method batch(
    Int $size
) returns Red::ResultSeqSeq
```

Returns a ResultSeqSeq containing ResultSeq that will return ResultSeqs with $size rows each (do not run the query)

### method create

```raku
method create(
    *%pars
) returns Mu
```

Creates a new element of that set

### method push

```raku
method push(
    *%pars
) returns Mu
```

Alias for `create`

### method delete

```raku
method delete() returns Mu
```

Deletes every row on that ResultSeq

### method save

```raku
method save() returns Mu
```

Saves any change on any element of that ResultSet

### method union

```raku
method union(
    $other
) returns Red::ResultSeq
```

unifies 2 ResultSeqs

### method intersect

```raku
method intersect(
    $other
) returns Red::ResultSeq
```

intersects 2 ResultSeqs

### method minus

```raku
method minus(
    $other
) returns Red::ResultSeq
```

Removes 1 ResultSeq elements from other ResultSeq

### method join

```raku
method join(
    Str(Any) $sep
) returns Mu
```

Join (Positional join)

### method join-model

```raku
method join-model(
    Str $model,
    |c
) returns Mu
```

Create a custom join (SQL join)

### method join-model

```raku
method join-model(
    Red::Model \model,
    &on,
    :$name = Code.new,
    *%pars where { ... }
) returns Mu
```

Create a custom join (SQL join)

### method ast

```raku
method ast(
    Bool :$sub-select
) returns Red::AST
```

Returns the AST that will generate the SQL

