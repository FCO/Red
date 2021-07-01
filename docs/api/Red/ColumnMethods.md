Red::ColumnMethods
------------------



Red::Column methods

### method starts-with

```perl6
method starts-with(
    $text
) returns Mu
```

Tests if that column value starts with a specific sub-string is usually translated for SQL as `column like 'substr%'`

### method ends-with

```perl6
method ends-with(
    $text
) returns Mu
```

Tests if that column value ends with a specific sub-string is usually translated for SQL as `column like '%substr'`

### method contains

```perl6
method contains(
    $text
) returns Mu
```

Tests if that column value contains a specific sub-string is usually translated for SQL as `column like %'substr%'`

### method substr

```perl6
method substr(
    $offset = 0,
    $size?
) returns Mu
```

Return a substring of the column value

### method year

```perl6
method year() returns Mu
```

Return the year from the date column

### method month

```perl6
method month() returns Mu
```

Return the month from the date column

### method day

```perl6
method day() returns Mu
```

Return the day from the date column

### method yyyy-mm-dd

```perl6
method yyyy-mm-dd() returns Mu
```

Return the date from a datetime, timestamp etc

### method AT-KEY

```perl6
method AT-KEY(
    $key where { ... }
) returns Mu
```

Return a value from a json hash key

### method DELETE-KEY

```perl6
method DELETE-KEY(
    $key where { ... }
) returns Mu
```

Delete and return a value from a json hash key

