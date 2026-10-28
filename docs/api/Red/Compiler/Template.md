### has Positional @.plan

A query expression compiled independently of SQL aliases and closure instances.

### method bind

```raku
method bind(
    $subject
) returns Red::Compiler::Template:D
```

Bind captures once; rebinding SQL aliases does not read the captures again.

