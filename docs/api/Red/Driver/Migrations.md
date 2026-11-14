

Backend hooks used by the migration coordinator and offline planner.

### method migration-lock-transaction

```raku
method migration-lock-transaction() returns Bool
```

True when acquiring the migration lock also starts the write transaction.

