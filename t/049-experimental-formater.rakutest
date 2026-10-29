use Test;
use Red <formatters>;
use Red::Formatter;

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

{
    my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
    my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
    my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
    my $driver              = @conf.shift;
    my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

	$*RED-DB.table-formatter = -> $ { "something_else" }
	is Bla.table-formatter("bla-ble-bli"), "something_else";
}

done-testing;
