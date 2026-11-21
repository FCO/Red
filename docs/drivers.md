# Available drivers

Red loads backends by name: `database "SQLite"` loads `Red::Driver::SQLite`.
Constructor arguments are passed directly to the driver. Use `red-defaults` for an
application default, or assign a driver to the dynamic `$*RED-DB` for a lexical scope.

| Backend | Name passed to Red | Distribution | Guide |
| --- | --- | --- | --- |
| SQLite | `SQLite` | Bundled with `Red`, uses `DBIish` | [SQLite](tutorials/sqlite.md) |
| PostgreSQL | `Pg` | [`Red::Driver::Pg`](https://github.com/FCO/Red-Driver-Pg), uses `DB::Pg` | [PostgreSQL](tutorials/postgresql.md) |
| MySQL | `MySQL` | [`Red::Driver::MySQL`](https://github.com/FCO/Red-Driver-MySQL), uses `DBIish` | [MySQL](tutorials/mysql.md) |
| DuckDB | `DuckDB` | [`Red::Driver::DuckDB`](https://github.com/FCO/Red-Driver-DuckDB), uses `DB::DuckDB` | [DuckDB](tutorials/duckdb.md) |

PostgreSQL, MySQL and DuckDB are separate distributions. Install a driver compatible
with your Red version; a source checkout may require coordinated driver checkouts.
See the [driver boundary](architecture/driver-boundary.md) for development details.
If loading a driver fails, Red raises `X::Red::Driver::NotInstalled`, preserving the
underlying cause. Check both the distribution and its native client dependencies.

## Testing and caching

`Mock` is bundled for tests. It delegates SQL translation to SQLite by default and
lets tests configure expected SQL and returned rows. It is not a database server.
See [its implementation](https://github.com/FCO/Red/blob/master/lib/Red/Driver/Mock.rakumod).

`Memory` is a bundled result-cache wrapper, loaded with the `cache` function rather
than `database`. `CommonSQL`, `Cache`, `CacheWithStrKey` and `CacheInvalidateOnWrite`
are support roles, not connection drivers. See [How to create a new cache](tutorials/new-cache.md)
for usage and consistency limitations, and [How to create a new driver](tutorials/new-driver.md)
for extending Red.
