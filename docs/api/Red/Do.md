Red::Do
=======

### multi sub red-defaults-from-config

```perl6
multi sub red-defaults-from-config() returns Mu
```

Loads Red configuration (mostly the database connection) from a json configuration json file. If the file isn't defined try to get it on `./.red.json`

### multi sub red-defaults-from-config

```perl6
multi sub red-defaults-from-config(
    $file where { ... }
) returns Mu
```

Loads Red configuration (mostly the database connection) from a json configuration json file. If the file isn't defined try to get it on `./.red.json`

### multi sub red-defaults

```perl6
multi sub red-defaults(
    Str $driver,
    |c is raw
) returns Mu
```

Sets the default connection to be used

### multi sub red-defaults

```perl6
multi sub red-defaults(
    *%drivers
) returns Mu
```

Sets the default connections to be used. The key is the name of the connection and the value the connection itself

### multi sub red-do

```perl6
multi sub red-do(
    *@blocks where { ... },
    Str :$with = "default",
    :$async
) returns Mu
```

Receives a block and optionally a connection name. Runs the block with the connection with that name

### multi sub red-do

```perl6
multi sub red-do(
    &block,
    Red::Driver:D :$with,
    :$async where { ... }
) returns Mu
```

Receives a block and optionally a connection name. Runs the block with the connection with that name synchronously

### multi sub red-do

```perl6
multi sub red-do(
    &block,
    Str:D :$with = "default",
    :$async! where { ... }
) returns Mu
```

Receives a block and optionally a connection name. Runs the block with the connection with that name asynchronously

### multi sub red-do

```perl6
multi sub red-do(
    *@blocks,
    Bool :$async,
    *%pars where { ... }
) returns Mu
```

Receives list of pairs with connection name and block or blocks (assuming the default connection) or named args where the name is the name of the connection Runs each block with the connection with that name

