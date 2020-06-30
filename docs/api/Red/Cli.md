### multi sub list-tables

```perl6
multi sub list-tables(
    Str :$driver!,
    *%pars
) returns Mu
```

Lists tables from database schema

### multi sub gen-stub-code

```perl6
multi sub gen-stub-code(
    Str :$schema-class,
    Str :$driver!,
    *%pars
) returns Mu
```

Generates models' code from database schema

### multi sub migration-plan

```perl6
multi sub migration-plan(
    Str :$model!,
    Str :$require = { ... },
    Str :$driver!,
    *%pars
) returns Mu
```

Generates models' code from database schema

### multi sub generate-code

```perl6
multi sub generate-code(
    Str :$path! where { ... },
    Str :$from-sql where { ... },
    Str :$schema-class,
    Bool :$print-stub = Bool::False,
    Bool :$no-relationships = Bool::False,
    Str :$driver!,
    *%pars
) returns Mu
```

Generates models' code from database schema

### multi sub prepare-database

```perl6
multi sub prepare-database(
    Bool :$populate,
    Str :$models!,
    Str :$driver!,
    *%pars
) returns Mu
```

Prepare database

