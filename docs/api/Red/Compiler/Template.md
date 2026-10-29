### has Positional @.plan

A query expression compiled independently of SQL aliases and closure instances.

### method validate-code

```raku
method validate-code(
    $actual,
    Code:D $expected
) returns Mu
```

Bind captures once; rebinding SQL aliases does not read the captures again.

