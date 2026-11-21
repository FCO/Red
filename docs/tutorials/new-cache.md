# How to create a new cache

Red's `Red::Driver::Cache` wraps a database driver and materializes SELECT rows.
This differs from `ResultSeq.cache` (materializing one result sequence) and the
[runtime query-plan cache](rakuast.md#runtime-query-plan-cache) (compiled plans,
not returned rows).

## Use the bundled Memory cache

```raku
use Red:api<2>;
use Red::Driver::Cache;

my $db = database 'SQLite';
my $*RED-DB = $db;

model Task {
    has Int $.id is serial;
    has Str $.title is column;
}

schema(Task).create;
Task.^create(:title<First>);
$*RED-DB = cache 'Memory' => \(:ttl(30)), $db;
say Task.^all.List;
say Task.^all.List;
```

`cache` accepts a cache name or `name => Capture` configuration and an existing
driver, driver name or `name => Capture` configuration. For example:

```raku
my $cached = cache 'Memory' => \(:ttl(30)),
    'SQLite' => \(:database('tasks.sqlite3'));
```

Create the schema through the underlying driver before installing the cache wrapper.

`Memory` has an integer TTL of 10 seconds by default. Its data is local to the
cache object and expires through a background timer. It tracks tables for
invalidation. The bundled `CacheInvalidateOnWrite` role intercepts **inserts only**;
updates, deletes, raw SQL and writes from other connections/processes do not
invalidate it automatically. Expiry is not a transactional consistency guarantee.
Use the underlying driver for work requiring current reads or transaction isolation.

## Implement an AST cache

Put a new class in `lib/Red/Driver/Cache/YourCache.rakumod`, register it in your
distribution's `META6.json`, and compose `Red::Driver::Cache`. The role supplies the
required `Red::Driver $.driver` attribute and delegates basic SQL operations.
Implement `multi method get-from-cache(Red::AST $ast)` and
`multi method set-on-cache(Red::AST $ast, @rows)`.

A hit must return a defined iterable of row hashes, including an empty array for
an empty result. A miss must return an undefined value such as `Nil`. The wrapper
prepares the underlying query on a miss, consumes its rows, stores them, then
returns an iterator over those rows. This eagerly materializes the full result;
account for memory usage and large queries.

Here is a loadable, deliberately minimal cache that always misses. It is useful
for checking the loading and delegation contract before adding storage:

```raku
use Red::AST;
use Red::Driver::Cache;

unit class Red::Driver::Cache::PassThrough does Red::Driver::Cache;

multi method get-from-cache(Red::AST $ast) {
    Nil
}

multi method set-on-cache(Red::AST $ast, @rows) {
    Nil
}
```

Save it as `lib/Red/Driver/Cache/PassThrough.rakumod`, then load it with
`cache 'PassThrough', database('SQLite')` using `raku -Ilib`.
Replace the two methods with storage/retrieval once your key and invalidation
policy are defined. Do not cache failures as empty results.

## String keys and invalidation

`Red::Driver::CacheWithStrKey` supplies AST-to-string translation and calls
`get-from-cache(Str $key, :$ast)` and `set-on-cache(Str $key, @rows, :$ast)`.
See the bundled
[Memory implementation](https://github.com/FCO/Red/blob/master/lib/Red/Driver/Cache/Memory.rakumod)
for these signatures. Unsupported key translations fall back to the underlying
driver; the built-in translator is not a complete key scheme for every Red AST.

For a new storage backend, include all result-affecting inputs in the key:
projection, tables, filters and their bound values/types, joins, ordering, grouping,
limit/offset, connection/database identity and any tenant/session context. Avoid
ambiguous delimiters and distinguish null from empty strings. A SQL plan key alone
cannot identify result data. Never share entries across connections just because
the SQL text matches.

You can compose `Red::Driver::CacheInvalidateOnWrite` and implement
`multi method invalidate(Str :$table!, *%columns)` to invalidate inserts. Full
consistency additionally requires handling updates/deletes, affected tables in
joins, external writes and commit/rollback timing. Consider bypassing caching
inside transactions. Add capacity/eviction limits, synchronization for concurrent
requests and a serialization policy if rows leave the process. Do not let callers
mutate the stored row objects through returned results.

The base wrapper delegates only a subset of driver methods. Review the
[driver contract](new-driver.md) before promising transparent support for catalogs,
migrations, notifications or transaction lifecycle methods. The cache wrapper's
`schema-reader` currently has no implementation.

## Verify the behavior

Test repeated reads, different bind values, empty results, unsupported AST bypass,
expiry and eviction, insert/update/delete invalidation, rollback and isolation
between connections. Compare results with the unwrapped driver, including regex
capability checks and errors. For distributed storage, also exercise unavailable
storage and serialization failures. The wrapper catches exceptions during SELECT
preparation and falls back to the driver; define and test your intended failure
policy instead of relying on that catch for every stage of execution.
