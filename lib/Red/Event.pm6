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
has Exception    $.error;
has              %.metadata;
