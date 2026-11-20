Red::GlobalEvents
-----------------

module Red::GlobalEvents
------------------------

Registry and listener bootstrap shared by global-notifiable models.

### sub register-model

```raku
sub register-model(
    Mu:U $model
) returns Mu
```

Register a model declared with C<is global-notifiable>.

### sub global-models

```raku
sub global-models() returns Array:D
```

Every global-notifiable model known in this process.

### sub model-for-name

```raku
sub model-for-name(
    Str:D $name
) returns Mu
```

Resolve the model named by a notification payload.

### sub warn-unsupported

```raku
sub warn-unsupported(
    Mu:U $model,
    Mu $driver
) returns Mu
```

Warn once per model/backend when a notification was requested but is unavailable.

### sub on-global-notification

```raku
sub on-global-notification(
    Mu $driver,
    %payload
) returns Mu
```

Turn a backend notification into a Red::Event delivered by the listening driver.

### sub ensure-global-listener

```raku
sub ensure-global-listener(
    Mu $driver,
    @models = Code.new
) returns Mu
```

Make sure a driver has one listener for all global-notifiable models.

### sub start-global-events

```raku
sub start-global-events(
    Mu :$with!
) returns Mu
```

Public entry point: start listening for global notifications on a driver.

