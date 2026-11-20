Red::Driver::Events
-------------------



Backend hooks for cross-process (multi-node) model events. Drivers that do not support notifications keep Red's original in-process event stream.

### method supports-global-events

```raku
method supports-global-events() returns Bool
```

Does this backend support global notifications?

### method global-event-triggers

```raku
method global-event-triggers(
    Mu:U $
) returns Array:D
```

DDL publishing inserts for one model. Each item is a C<name => SQL> pair; the SQL must be idempotent so direct table creation and migrations can share it.

### method install-global-event-triggers

```raku
method install-global-event-triggers(
    @models
) returns Mu
```

Install notification DDL for the supplied models.

### method global-event-listener-driver

```raku
method global-event-listener-driver() returns Mu
```

Driver used by the global-event listener. Transaction-scoped drivers can override this to return a stable connection for materializing notifications.

### method listen-global-events

```raku
method listen-global-events(
    @models,
    &on-event
) returns Mu
```

Start listening and call C<&on-event> with a hash containing C<model> and C<ids>. The returned value is kept as the listener handle.

### method migration-drop-global-event-trigger

```raku
method migration-drop-global-event-trigger(
    Str $table,
    Str $name
) returns Str:D
```

SQL removing one notification trigger definition (used by migrations).

