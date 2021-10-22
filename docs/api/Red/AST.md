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

