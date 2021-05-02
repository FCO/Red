Red::Utils
----------

### sub snake-to-kebab-case

```raku
sub snake-to-kebab-case(
    Str(Any) $_
) returns Str
```

Accepts a string and converts snake case (`foo_bar`) into kebab case (`foo-bar`).

### sub kebab-to-snake-case

```raku
sub kebab-to-snake-case(
    Str(Any) $_
) returns Str
```

Accepts a string and converts kebab case (`foo-bar`) into snake case (`foo_bar`).

### sub camel-to-snake-case

```raku
sub camel-to-snake-case(
    Str(Any) $_
) returns Str
```

Accepts a string and converts camel case (`fooBar`) into snake case (`foo_bar`).

### sub camel-to-kebab-case

```raku
sub camel-to-kebab-case(
    Str(Any) $_
) returns Str
```

Accepts a string and converts camel case (`fooBar`) into kebab case (`foo-bar`).

### sub kebab-to-camel-case

```raku
sub kebab-to-camel-case(
    Str(Any) $_
) returns Str
```

Accepts a string and converts kebab case (`foo-bar`) into camel case (`fooBar`).

### sub snake-to-camel-case

```raku
sub snake-to-camel-case(
    Str(Any) $_
) returns Str
```

Accepts a string and converts snake case (`foo_bar`) into camel case (`fooBar`).

