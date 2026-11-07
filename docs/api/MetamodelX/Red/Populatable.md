### method fixture-populate

```raku
method fixture-populate(
    $model,
    :@rows!,
    Bool :$deflated = Bool::False
) returns Mu
```

Insert explicit fixture rows. Deflated rows use the same hydration rules as queries.

