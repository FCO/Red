

Base role to DB statements Returned by .query

### method execute

```perl6
method execute(
    *@binds
) returns Mu
```

Execute the pre-prepared query

### method stt-row

```perl6
method stt-row(
    $
) returns Hash(Any)
```

How to get a row must be implemented

### method row

```perl6
method row() returns Mu
```

Get the next row

