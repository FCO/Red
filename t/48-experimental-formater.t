use Test;
use Red <formatters>;
use Red::Formatter;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

class Bla does Red::Formatter {
    method experimental-formatter { True }
}

is Bla.column-formatter("bla-ble-bli"), "bla_ble_bli";
is Bla.table-formatter("BlaBleBli"), "bla_ble_bli";

model BleBli {
    has $.a-e-i-o-u is column
}

is BleBli.^table, "ble_bli";
is BleBli.^attributes.head.column.name, "a_e_i_o_u";

{
	my &*RED-TABLE-FORMATTER  = -> $name { "RED_TABLE_$name" }
	my &*RED-COLUMN-FORMATTER = -> $name { "`$name`" }

	is Bla.column-formatter("bla-ble-bli"), "`bla-ble-bli`";
	is Bla.table-formatter("BlaBleBli"), "RED_TABLE_BlaBleBli";

	model BloBlu {
	    has $.a-e-i-o-u is column
	}

	is BloBlu.^table, "RED_TABLE_BloBlu";
	is BloBlu.^attributes.head.column.name, "`a-e-i-o-u`";
}

{
	my $*RED-DB = class :: { method table-name-formatter($) { "not-bla" } }.new;

	is Bla.table-formatter("bla-ble-bli"), "not-bla";
}

done-testing;
