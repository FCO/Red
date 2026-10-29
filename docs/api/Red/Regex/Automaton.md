class Red::Regex::Automaton
---------------------------

Data-only Thompson automata, shared by SQL evaluation and dialect lowering.

### method render

```raku
method render(
    &render
) returns Str:D
```

Eliminate states to render regular conjunctions for native regex engines. Resource limits fail explicitly before constructing an unbounded pattern.

