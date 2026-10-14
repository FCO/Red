### method pg-jsonb-path

```raku
method pg-jsonb-path(
    Red::AST $path
) returns Mu
```

Builds a bound text array so JSON keys never become SQL syntax.

### multi method translate

```raku
multi method translate(
    Red::Column $col where { ... },
    "select",
    Str :$RED-OVERRIDE-COLUMN-AS-PREFIX
) returns Mu
```

Ask DB::Pg for serialized JSON so strings and JSON null survive inflation.

### multi method translate

```raku
multi method translate(
    Red::AST::Infix $_ where { ... },
    $context?
) returns Mu
```

JSON arithmetic uses SQL numbers; comparisons with scalars use the scalar's type.

