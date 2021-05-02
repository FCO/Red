### sub hash-to-cond

```raku
sub hash-to-cond(
    %val
) returns Mu
```

Transform a hash into filter (Red::AST)

### sub found-bool

```raku
sub found-bool(
    @values,
    $try-again is rw,
    %bools,
    CX::Red::Bool $ex
) returns Mu
```

Found a boolean while trying to find what's hapenning inside a block

### sub what-does-it-do

```raku
sub what-does-it-do(
    &func,
    \type
) returns Hash
```

Tries to find what a block do

