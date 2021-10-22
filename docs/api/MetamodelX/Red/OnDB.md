MetamodelX::Red::OnDB
---------------------

### method is-on-db

```raku
method is-on-db(
    \instance
) returns Mu
```

Checks if the instance of model has a record in the database or not. For example, `Person.^create(...).^is-on-db` returns True, because `^create` was called, but `Person.new(...).^is-on-db` will return False, because the created object does not have a representation in the database without calls to `^create` or `^save` done.

### method saved-on-db

```raku
method saved-on-db(
    \instance
) returns Mu
```

Sets that that object is on DB

