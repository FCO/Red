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

Tests if that column value contains a specific sub-string #| is usually translated for SQL as `column like %'substr%'`

