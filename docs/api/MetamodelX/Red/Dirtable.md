### method set-dirty

```perl6
method set-dirty(
    \obj,
    $attr
) returns Mu
```

Receives a Set of attributes ans set this attributes as dirt

### method is-dirty

```perl6
method is-dirty(
    Any:D \obj
) returns Bool
```

Returns `True` is the object is dirt

### method dirty-columns

```perl6
method dirty-columns(
    Any:D \obj
) returns Mu
```

Returns the dirt columns

### method clean-up

```perl6
method clean-up(
    Any:D \obj
) returns Mu
```

Cleans up the object

