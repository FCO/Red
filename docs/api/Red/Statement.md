

Base role to DB statements Returned by .query

### method execute

```raku
method execute(
    *@binds
) returns Mu
```

Execute the pre-prepared query

### method stt-row

```raku
method stt-row(
    $
) returns Hash(Any)
```

How to get a row must be implemented

### method row

```raku
method row() returns Mu
```

Get the next row

