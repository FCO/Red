use Red;

class Red::Configuration {
    has Bool()      $.debug        = True;
    has IO()        $.lib-path     = ".".IO;
    has Str         $.driver-name  = "SQLite";
    has             %.driver-attrs is Map;
    has Red::Driver $.driver       = database $!driver-name, |%!driver-attrs;
    has             @.requires;
    has             @.models;
    has Red::Schema $.schema       = schema @!models;
}

use Configuration Red::Configuration;
