

Base role to DB statements Returned by .query

### method guarded-by

```raku
method guarded-by(
    Mu:D $guard
) returns Mu
```

Attaches the lifetime of the transaction which prepared this statement.

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

