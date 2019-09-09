### multi sub database

```perl6
multi sub database(
    Str $type,
    |c is raw
) returns Mu
```

Receives a driver name and parameters to creates it

### multi sub database

```perl6
multi sub database(
    Str $type,
    $dbh
) returns Mu
```

Receives a driver name and a dbh and creates a driver

