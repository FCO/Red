class Red::Regex
----------------

A data-only regex tree. Drivers decide which operations their engine supports.

### method literal-filter

```raku
method literal-filter() returns Hash
```

Infer literal-only filters so drivers can use string operations directly.

### method literal-text

```raku
method literal-text(
    $tree = Code.new
) returns Mu
```

Fixed literal assertions can also be compiled without a native regex engine.

