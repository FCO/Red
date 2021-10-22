Red::AST::Optimizer::AND
------------------------

### method optimize

```raku
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x > 1 AND x > 10 ==> x > 10

### method optimize

```raku
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x < 1 AND x < 10 ==> x < 1

### method optimize

```raku
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x > 10 AND x < 1 ==> False

### method optimize

```raku
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x < 1 AND x > 10 ==> False

### method optimize

```raku
method optimize(
    Red::Column $left,
    Red::AST::Not $right,
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

