Red::Migration::SQL
-------------------

### sub statements

```raku
sub statements(
    Str $source,
    Str :$dialect = "SQL"
) returns Array
```

Split SQL into ordered executable statements while respecting quoted strings, comments and driver-enabled dollar quoting. Reject transaction commands, client directives and stored-program protocols the migration executor cannot safely handle.

