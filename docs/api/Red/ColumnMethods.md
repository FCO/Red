Red::ColumnMethods
------------------



Red::Column methods

### method starts-with

```raku
method starts-with(
    Str(Any) $text
) returns Mu
```

Tests if that column value starts with a specific sub-string is usually translated for SQL as `column like 'substr%'`

### method ends-with

```raku
method ends-with(
    Str(Any) $text
) returns Mu
```

Tests if that column value ends with a specific sub-string is usually translated for SQL as `column like '%substr'`

### method contains

```raku
method contains(
    Str(Any) $text
) returns Mu
```

Tests if that column value contains a specific sub-string is usually translated for SQL as `column like %'substr%'`

### method contains

```raku
method contains(
    $value
) returns Mu
```

Tests whether a JSON document contains another JSON value.

### method elems

```raku
method elems() returns Mu
```

Counts JSON members; scalars and null have one element, absent paths have none.

### method elems

```raku
method elems() returns Mu
```

A non-JSON scalar has one element, including SQL NULL.

### method lc

```raku
method lc() returns Mu
```

Return a lowercased string

### method fc

```raku
method fc() returns Mu
```

Return a lowercased string

### method uc

```raku
method uc() returns Mu
```

Return a uppercased string

### method substr

```raku
method substr(
    $offset = Code.new,
    $size?
) returns Mu
```

Return a substring of the column value

### method substr

```raku
method substr(
    $offset = Code.new,
    $size?
) returns Mu
```

Return a substring of the column value

### method index

```raku
method index(
    $needle
) returns Mu
```

Return a index of the column value

### method index

```raku
method index(
    $needle
) returns Mu
```

Return a index of the column value

### method year

```raku
method year() returns Mu
```

Return the year from the date column

### method month

```raku
method month() returns Mu
```

Return the month from the date column

### method day

```raku
method day() returns Mu
```

Return the day from the date column

### method yyyy-mm-dd

```raku
method yyyy-mm-dd() returns Mu
```

Return the date from a datetime, timestamp etc

### method AT-KEY

```raku
method AT-KEY(
    $key where { ... }
) returns Mu
```

Return a value from a json hash key

### method DELETE-KEY

```raku
method DELETE-KEY(
    $key where { ... }
) returns Mu
```

Delete and return a value from a json hash key

### method EXISTS-KEY

```raku
method EXISTS-KEY(
    $key
) returns Mu
```

Tests for a JSON key, including keys whose value is JSON null.

### method EXISTS-POS

```raku
method EXISTS-POS(
    $index
) returns Mu
```

Tests for a JSON array index, including elements whose value is JSON null.

### method DELETE-POS

```raku
method DELETE-POS(
    $index
) returns Mu
```

Deletes and returns an element from a JSON array.

### method ASSIGN-POS

```raku
method ASSIGN-POS(
    $index,
    $value
) returns Mu
```

Returns a value from a json array index

