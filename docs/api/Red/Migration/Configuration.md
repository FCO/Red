Red::Migration::Configuration
-----------------------------

### method model-types

```raku
method model-types() returns Array
```

Resolve configured model types or module names and return Red model type objects. Reject instances and values that are not Red models.

### method load

```raku
method load(
    IO(Any) $file
) returns Red::Migration::Configuration
```

Load a trusted project configuration through the Configuration reader and require a Red::Migration::Configuration result.

### sub configuration-api

```raku
sub configuration-api() returns Mu
```

Initialize the migration Configuration root when needed and generate its builder and reader exports without replacing an existing application configuration singleton.

