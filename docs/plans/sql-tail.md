# SQL-backed tail

Status: implemented; regression coverage is in `t/89-sql-tail.rakutest`.

## Behavior

- `tail(n)` returns a lazy ResultSeq containing the last n elements in their
  original order.
- Honor explicit sorting. Without sorting, use the primary key in ascending
  order, including composite primary keys.
- `tail()` executes the query and returns the last projected value or model,
  preserving the current empty-query behavior.
- Without an explicit order or available primary key, retain the in-memory
  behavior. Throw a typed exception when `$*RED-FALLBACK = False`.
- Keep inherited forms such as Callable arguments in memory.

## Implementation

- Represent ordering expressions and directions separately. Normalize the
  existing negative-expression convention for descending order.
- Preserve row identity as internal metadata through projections. Export keys
  across SELECT boundaries as hidden fields, without adding them to results.
- Aggregates, DISTINCT, and grouping invalidate the original row identity;
  require explicit ordering or use the fallback for these queries.
- Reverse every ordering component, apply LIMIT n, wrap the selection, and
  restore the original order in the outer SELECT.
- Preserve any preceding head/skip selection in a separate boundary before
  applying tail.
- Fuse subsequent safe maps and filters into the outer SELECT. Never push
  those filters before the selection of the last elements.
- Preserve converters, types, unique aliases, bind ordering, and independent
  sibling queries. Export ordering values without ASC/DESC in selected fields.

Example:

```sql
SELECT last_rows.data_1 * 10 AS bla
FROM (
    SELECT bla.bla AS data_1
    FROM bla
    WHERE bla.bla > 1
    ORDER BY bla.bla DESC
    LIMIT 7
) AS last_rows
WHERE last_rows.data_1 * 10 < 100
  AND last_rows.data_1 * 10 <= 50
ORDER BY last_rows.data_1 ASC
```

## Verification

- Cover the complete example, returning [40, 50], with a lazy ResultSeq and
  exactly one SQL execution.
- Cover models, scalars, and containers; ascending, descending, and composite
  ordering; implicit simple/composite primary keys; and NULLs in both drivers.
- Cover tail(0), empty queries, oversized counts, tail(), repeated tails,
  head/skip combinations, and subsequent filters and sorting.
- Verify hidden fields, converters, binds, fallback without keys, and typed
  rejection when fallback is disabled.
- Run the full SQLite suite and relevant PostgreSQL tests. Update the cookbook
  and Changes in English.

## Defaults

- Introduce implicit primary-key ordering only when tail needs it, without
  changing the global ordering of model queries.
- Do not append automatic tie-breakers to explicit ordering. Include primary
  keys explicitly when deterministic ordering of ties is required.
- Respect each driver's NULL ordering when reversing and restoring directions.
