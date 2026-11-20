use Red::Model;
#| Represents a event
unit class Red::Event;

#| Database driver
has              $.db;
#| Database driver's name
has Str          $.db-name;
#| Database driver type name
has Str          $.driver-name;
has Str          $.name;
has              $.data;
has              @.bind;
has Red::Model:U $.model;
has Red::Model   $.origin;
#| Lazily resolves the row returned by the database (with generated ids).
has Callable     $.materialize-origin;
has Exception    $.error;
has              %.metadata;
#| True when the event came from another node through the driver's notification backend.
has Bool         $.global = False;
#| Id attribute names carried by a global notification.
has              %.ids;
