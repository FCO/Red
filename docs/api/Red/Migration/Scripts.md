Red::Migration::Scripts
-----------------------

### sub read-direction

```raku
sub read-direction(
    IO(Any) $root,
    Str $direction,
    Str $dialect
) returns Hash
```

Read one SQL direction in numeric file order, accepting either legacy up.sql/down.sql or numbered directory files. Return statements, file identities and checksums; reject mixed formats and duplicate numbers.

### sub write-direction

```raku
sub write-direction(
    IO(Any) $root,
    Str $direction,
    Str $source
) returns Mu
```

Write generated SQL to direction/001-schema.sql, replacing a legacy single-file direction when present.

