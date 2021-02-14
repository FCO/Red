use Test;
use Red <refreshable>;

model TestModel {
    has Int $.id   is id;
    has Int $.num  is column is rw;
    has Str $.str  is column is rw;
    has     $.num2 is column is rw;
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

red-defaults "SQLite";
TestModel.^create-table;
my $a = TestModel.^create: :num(-1), :str<pla>, :num2(-99);

sub change($a) {
	my $num  = 1000.rand.Int;
	my $str  = ("bla" .. "blz").pick;
	my $num2 = 1000.rand.Int;

	$a.num  = $num;
	$a.str  = $str;
	$a.num2 = $num2;

	is $a.num , $num;
	is $a.str , $str;
	is $a.num2, $num2;

	$num, $str, $num2
}

my ($num, $str, $num2) = change $a;
$a.^refresh: "num";
is $a.num , -1;
is $a.str , $str;
is $a.num2, $num2;

($num, $str, $num2) = change $a;
$a.^refresh: "num", "str";
is $a.num, -1;
is $a.str, "pla";
is $a.num2, $num2;

($num, $str, $num2) = change $a;
$a.^refresh: <num str>;
is $a.num, -1;
is $a.str, "pla";
is $a.num2, $num2;

($num, $str, $num2) = change $a;
$a.^refresh;
is $a.num, -1;
is $a.str, "pla";
is $a.num2, -99;

done-testing
