class Red::Event
----------------

Represents a event

### has Mu $.db

Database driver

### has Str $.db-name

Database driver's name

### has Str $.driver-name

Database driver type name

### has Callable $.materialize-origin

Lazily resolves the row returned by the database (with generated ids).

### has Bool $.global

True when the event came from another node through the driver's notification backend.

### has Associative %.ids

Id attribute names carried by a global notification.

