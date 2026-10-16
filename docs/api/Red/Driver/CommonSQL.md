### method indexes-for-table

```raku
method indexes-for-table(
    Str $table
) returns Array
```

Return catalog entries with name, uniqueness, ordered keys and partial flag.

### method index-catalog-rows

```raku
method index-catalog-rows(
    $statement
) returns Seq
```

Drivers may terminate row iteration with Nil or IterationEnd.

### method index-key-fingerprint

```raku
method index-key-fingerprint(
    Str $key
) returns Str
```

Dialects can normalize their own catalog's expression spelling here.

### method json-path-items

```raku
method json-path-items(
    Red::AST $path
) returns List
```

Returns the AST components of a JSON path without evaluating dynamic keys.

