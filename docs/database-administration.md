# Database administration

The `red` CLI delegates administration to the configured connection's driver:

```sh
red create-user app --connection=admin --password="$APP_DATABASE_PASSWORD"
red create-role readers --connection=admin
red create-database app --connection=admin
```

For a server that is not configured yet, pass `--driver` and constructor
parameters with the `--connect-` prefix. No configuration file is required:

```sh
red create-database app --driver=Pg --connect-host=localhost --connect-port=5432 --connect-dbname=postgres --connect-user=postgres --connect-password="$ADMIN_PASSWORD"
red create-database app --driver=MySQL --connect-host=localhost --connect-user=root --connect-password="$ADMIN_PASSWORD" --save-as=production
```

`--connect-dbname` selects the existing PostgreSQL database used for the
administrative connection; the positional name is the database to create.
Use `--connect-database` for drivers whose constructor takes `database`.
`--driver` and `--connection` are mutually exclusive. Connection parameters go
to the driver constructor; other backend options go to the creation method.
For `create-user`, `--connect-password` authenticates the administrator and
`--password` sets the new user's password. With `--save` or `--save-as`, a missing
configuration file is created after successful database/user creation.

Use `--config=path/to/red.rakuconf` to select another configuration file.
The default connection is `default`. An administrative connection must point
to an existing database and have permission to perform the requested operation.
Use `--save` with `create-database` or `create-user` to save a connection
using the database or user name. Use `--save-as=application` to choose an
alternative connection name (which takes precedence over `--save`). This adds a
named connection to the same configuration after successful creation:

```sh
red create-database app --connection=admin --save
red create-user app --connection=app --password="$APP_DATABASE_PASSWORD" --save-as=app-user
```

The saved connection inherits the source connection's settings and replaces the
database name or user and password. Existing connection names are rejected before
creation. The default connection is unchanged. The configuration remains executable
Raku; its original contents are wrapped and the new lazy connection is appended.
For `create-user`, the supplied password is stored in the configuration file.
Without `--save` or `--save-as`, these commands leave the configuration unchanged.

The driver receives the name as a positional argument and all additional
options as named arguments. No SQL dialect selection happens in the CLI.

| Driver | Database | User | Role |
| --- | --- | --- | --- |
| SQLite | Creates a persistent file; refuses an existing file | Unsupported | Unsupported |
| PostgreSQL | Supports optional `--owner=role` | Requires `--password` | Creates a non-login role |
| MySQL | Creates a database | Requires `--password`; optional `--host` (default `%`) | Optional `--host` (default `%`) |

PostgreSQL and MySQL support is supplied by their separate driver distributions.
These commands do not grant database or table privileges.

Drivers implement `create-database(Str:D $name, ...)`,
`create-user(Str:D $name, ...)`, and `create-role(Str:D $name, ...)`.
Each driver owns its SQL, quoting, supported options, and backend restrictions.
The base driver throws `X::Red::Administration` for unsupported operations.
Cache wrappers forward these methods to their underlying driver.
