### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x > 1 AND x > 10 ==> x > 10

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x < 1 AND x < 10 ==> x < 1

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x > 10 AND x < 1 ==> False

### method optimize

```perl6
method optimize(
    Red::AST::Infix $left where { ... },
    Red::AST::Infix $right where { ... },
    1
) returns Mu
```

x < 1 AND x > 10 ==> False

### method optimize

```perl6
method optimize(
    Red::Column $left,
    Red::AST::Not $right,
    1
) returns Mu
```

a.b AND NOT(a.b) ==> True

### method optimize

```perl6
method optimize(
    Red::AST::Not $left,
    Red::Column $right,
    1
) returns Mu
```

NOT(a.b) AND a.b ==> True

