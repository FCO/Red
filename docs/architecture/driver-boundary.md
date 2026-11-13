# Driver boundary

Red owns query and migration coordination, intermediate ASTs, and shared SQL behavior.
SQLite is bundled. Other backends own SQL lowering, catalog normalization, native client
arguments, sequence synchronization, migration locking and temporary database provisioning.

`Red::Driver` supplies shared defaults. External drivers override backend operations through
`Red::Driver::Migrations` and their own support roles. Unsupported operations must throw typed
exceptions. Core code must select capabilities through methods rather than backend names.

Regex trees remain in `Red::Regex`; native rendering belongs to
`Red::Driver::<name>::Regex`. The compatibility `render(:dialect(...))` entry point loads that
renderer dynamically. Each renderer implements only its own engine's syntax and limitations.

## Coordinated validation and release

This extraction changes the driver contract. Validate the core together with the modified
Pg, MySQL and DuckDB checkouts. For sibling checkouts, prepend their libraries when running
backend tests, for example:

```sh
raku -Ilib -I../Red-Driver-Pg/lib ../Red-Driver-Pg/t/driver-support.rakutest
raku -Ilib -I../Red-Driver-MySQL/lib ../Red-Driver-MySQL/t/driver-support.t
```

Use each driver's test runner for database isolation. Run `static` on each changed Raku unit
before execution, then the core suite and backend integration suites.

Before publishing, commit the coordinated driver changes and update the pinned driver revisions
in `.github/workflows/matrix.yaml` to those compatible commits. The existing pins predate this
contract and cannot validate the new core. Do not publish the new core against those old driver
revisions. No replacement hashes are recorded until the driver commits exist.

## Driver-owned definitions

PostgreSQL range ASTs, exclusion constraints, `sql-range` and `is exclude` live in
`Red::Driver::Pg::AST` and `Red::Driver::Pg::Schema`. Applications using those declarations
import `use Red::Driver::Pg::Schema;` after `use Red`. Core owns only generic AST extension
and constraint-builder interfaces. Regex compatibility calls require an explicit `:dialect`;
the core no longer selects a backend by default.
