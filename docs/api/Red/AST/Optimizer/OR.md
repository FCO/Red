Red::AST::Optimizer::OR
-----------------------

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    Int $ where { ... }
) returns Mu
```

x > 1 OR x > 10 ==> x > 10

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    Int $ where { ... }
) returns Mu
```

x < 1 OR x < 10 ==> x < 1

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    Int $ where { ... }
) returns Mu
```

x < 10 OR x > 1 ==> True

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    Int $ where { ... }
) returns Mu
```

x > 1 OR x < 10 ==> True

### method optimize

```perl6
method optimize(
    $left where { ... },
    $right where { ... },
    Int $ where { ... }
) returns Mu
```

a.b OR NOT(a.b) ==> True

### method optimize

```perl6
method optimize(
    $left where { ... },
    $right where { ... },
    Int $ where { ... }
) returns Mu
```

NOT(a.b) AND a.b ==> True

