### multi sub list-tables

```raku
multi sub list-tables(
    Str :$driver!,
    *%pars
) returns Mu
```

Lists tables from database schema

### multi sub gen-stub-code

```raku
multi sub gen-stub-code(
    Str :$schema-class,
    Str :$driver!,
    *%pars
) returns Mu
```

Generates stub code to access models from database schema

### multi sub migration-plan

```raku
multi sub migration-plan(
    Str :$model!,
    Str :$require = Code.new,
    Str :$driver!,
    *%pars
) returns Mu
```

Generates migration plan to upgrade database schema

### multi sub generate-code

```raku
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

```raku
multi sub prepare-database(
    Bool :$populate,
    Str :$models!,
    Str :$driver!,
    *%pars
) returns Mu
```

Prepare database

