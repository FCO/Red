Red::HiddenFromSQLCommenting
----------------------------

### multi sub trait_mod:<is>

```raku
multi sub trait_mod:<is>(
    Method $r,
    Bool :$hidden-from-sql-commenting!
) returns Mu
```

Trait for not adding SQL comments for this function

