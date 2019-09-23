use Red::Model;
unit class Red::Event;

has              $.db;
has Str          $.db-name;
has Str          $.driver-name;
has Str          $.name;
has              $.data;
has Red::Model:U $.model;
has Red::Model   $.origin;
has Exception    $.error;