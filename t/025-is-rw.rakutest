use Red;
use Test;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

model Writable is rw {
    has Int $!id is serial;
    has Str $.value is column;
}

schema(Writable).drop;
Writable.^create-table;

my $a = Writable.^create: :value<bla>;

is $a.value, "bla";
lives-ok { $a.value = "ble" };
lives-ok { $a.^save }
is $a.value, "ble";

done-testing;
