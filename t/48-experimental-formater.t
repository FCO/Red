use Test;
use Red <formaters>;
use Red::Formater;

class Bla does Red::Formater {
    method experimental-formater { True }
}

is Bla.column-formater("bla-ble-bli"), "bla_ble_bli";
is Bla.table-formater("BlaBleBli"), "bla_ble_bli";

model BleBli {
    has $.a-e-i-o-u is column
}

is BleBli.^table, "ble_bli";
is BleBli.^attributes.head.column.name, "a_e_i_o_u";

my &*RED-TABLE-FORMATER  = -> $name { "RED_TABLE_$name" }
my &*RED-COLUMN-FORMATER = -> $name { "`$name`" }

is Bla.column-formater("bla-ble-bli"), "`bla-ble-bli`";
is Bla.table-formater("BlaBleBli"), "RED_TABLE_BlaBleBli";

model BloBlu {
    has $.a-e-i-o-u is column
}

is BloBlu.^table, "RED_TABLE_BloBlu";
is BloBlu.^attributes.head.column.name, "`a-e-i-o-u`";

done-testing;
