Red::AST::Optimizer::AND
------------------------

### method optimize

```raku
method optimize(
    Red::AST::Ge $ (Red::AST :left($big), Red::AST :right($columnl), Any |),
    Red::AST::Ge $ (Red::AST :left($columnr), Red::AST :right($small), Any |),
    1
) returns Mu
```

1 <= x <= 10 x >= 1 AND x <= 10 ==> x between 1 and 10

### method optimize

```raku
method optimize(
    Red::AST::Le $ (Red::AST :left($small), Red::AST :right($columnl), Any |),
    Red::AST::Le $ (Red::AST :left($columnr), Red::AST :right($big), Any |),
    1
) returns Mu
```

10 >= x >= 1 x <= 10 AND x >= 1 ==> x between 1 and 10

### method optimize

```raku
method optimize(
    Red::AST::Infix $left (Red::AST :left($ll), Red::AST :right($lr), Any |) where { ... },
    Red::AST::Infix $right (Red::AST :left($rl) where { ... }, Red::AST :right($rr), Any |) where { ... },
    $
) returns Mu
```

x > 1 AND x > 10 ==> x > 10

### method optimize

```raku
method optimize(
    Red::AST::Infix $left (Red::AST :left($ll), Red::AST :right($lr), Any |) where { ... },
    Red::AST::Infix $right (Red::AST :left($rl) where { ... }, Red::AST :right($rr), Any |) where { ... },
    $
) returns Mu
```

x < 1 AND x < 10 ==> x < 1

### method optimize

```raku
method optimize(
    Red::AST::Infix $left (Red::AST :left($ll), Red::AST :right($lr), Any |) where { ... },
    Red::AST::Infix $right (Red::AST :left($rl) where { ... }, Red::AST :right($rr), Any |) where { ... },
    $
) returns Mu
```

x > 10 AND x < 1 ==> False

### method optimize

```raku
method optimize(
    Red::AST::Infix $left (Red::AST :left($ll), Red::AST :right($lr), Any |) where { ... },
    Red::AST::Infix $right (Red::AST :left($rl) where { ... }, Red::AST :right($rr), Any |) where { ... },
    $
) returns Mu
```

x < 1 AND x > 10 ==> False

### method optimize

```raku
method optimize(
    Red::Column $left,
    Red::AST::Not $right where { ... },
    1
) returns Mu
```

a.b AND NOT(a.b) ==> True

### method optimize

```raku
method optimize(
    Red::AST::Not $left,
    Red::Column $right,
    1
) returns Mu
```

NOT(a.b) AND a.b ==> True

### method optimize

```raku
method optimize(
    Red::AST $left,
    Red::AST $right where { ... },
    1
) returns Mu
```

X AND NOT(X) => False

### method optimize

```raku
method optimize(
    Red::AST::AND $left,
    Red::AST $right where { ... },
    1
) returns Mu
```

(X AND NOT(Y)) AND Y ==> False

### method optimize

```raku
method optimize(
    Red::AST $left,
    Red::AST::AND $right where { ... },
    1
) returns Mu
```

X AND (NOT(X) AND Y) ==> False

