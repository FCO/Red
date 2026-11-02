Red::Migration::Environment
---------------------------

### sub test-database

```raku
sub test-database() returns Mu
```

Open the disposable connection described by RED_MIGRATION_TEST. Return Nil when no test context is active so application code can select its normal configuration.

### sub temporary-database

```raku
sub temporary-database(
    Str $driver,
    %server,
    &body,
    Bool :$keep = Bool::False
) returns Mu
```

Provision an isolated SQLite file or uniquely named native database and call the supplied body with its connection, context file and parameters. Clean up on success or failure unless keep is requested; native servers need database creation and removal privileges.

### sub provision-database

```raku
sub provision-database(
    Str $driver,
    %server,
    &body,
    %environment,
    Bool :$keep
) returns Mu
```

Isolate migration context changes while preserving the caller's environment, including native database credentials and library paths. Capture it before declaring the dynamic environment.

