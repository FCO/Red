Red::AST
--------



Base role for all Red::AST::*

### method not

```raku
method not() returns Mu
```

Returns the nagation of the AST.

### method Bool

```raku
method Bool() returns Bool
```

If inside of a block for ResultSeq mothods throws a control exception and populates all possibilities

### method transpose-first

```raku
method transpose-first(
    &func
) returns Mu
```

Find the first AST node folowing the rule

### method transpose-grep

```raku
method transpose-grep(
    &func
) returns Mu
```

Find AST nodes folowing the rule

### method transpose

```raku
method transpose(
    &func
) returns Mu
```

Transposes the AST tree running the function.

### method tables

```raku
method tables() returns Mu
```

Returns a list with all the tables used on the AST

