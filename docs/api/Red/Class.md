class Red::Class
----------------

Base class for Red methods

### method instance

```perl6
method instance() returns Red::Class
```

Return a instance of Red::Class

### has Supply $.events

Supply that emit Red events

### method register-supply

```perl6
method register-supply(
    Supply $_
) returns Mu
```

Register a new supply to send events

