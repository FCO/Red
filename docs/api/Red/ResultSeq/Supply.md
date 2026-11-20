Red::ResultSeq::Supply
----------------------

module Red::ResultSeq::Supply
-----------------------------

Shared "live" supplies for ResultSeq queries.

### sub supply-identity

```raku
sub supply-identity(
    $value
) returns Mu
```

Identity used to remove the duplicate emitted at the snapshot/live boundary.

### sub source-model

```raku
sub source-model(
    \rs
) returns Mu
```

Returns the original model of a ResultSeq, unwrapping specialised projection models.

### sub event-model

```raku
sub event-model(
    Red::Event $event
) returns Mu
```

Returns the model associated with an insert event.

### sub instance-from-event

```raku
sub instance-from-event(
    Red::Event $event
) returns Mu
```

Rebuilds the instance created by an insert event.

### sub build-live

```raku
sub build-live(
    \rs,
    $driver
) returns Supply
```

Builds the pipeline that turns insert events into query results.

### sub live-supply-for

```raku
sub live-supply-for(
    \rs,
    Red::AST $ast,
    $driver
) returns Supply
```

Returns the live Supply for this AST, binds and driver, creating it if needed.

