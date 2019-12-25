use Red;
use Test;

my $*RED-DB = database "SQLite";

model Writable is rw {
    has Int $!id is serial;
    has Str $.value is column;
}

Writable.^create-table;

my $a = Writable.^create: :value<bla>;

is $a.value, "bla";
lives-ok { $a.value = "ble" };
lives-ok { $a.^save }
is $a.value, "ble";

done-testing;
