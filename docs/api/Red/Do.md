This module is experimental, to use it, do:
===========================================

```perl6
use Red <red-do>;
```

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
    &block,
    :$use = "default"
) returns Mu
```

Receives a block and optionally a connection name. Runs the block with the connection with that name

### multi sub red-do

```perl6
multi sub red-do(
    *@blocks
) returns Mu
```

Receives list of pairs with connection name and block Runs each block with the connection with that name

