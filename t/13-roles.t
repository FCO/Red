use Test;
use Red;

my $*RED-DB = database "Mock";
$*RED-DB.die-on-unexpected;

role Bla { has $.a is column }

model Ble does Bla {}

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    CREATE TABLE ble(
        a varchar(255) NOT NULL
    )
EOSQL

Ble.^create-table;

model Bli does Bla {}

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    CREATE TABLE bli(
        a varchar(255) NOT NULL
    )
EOSQL

Bli.^create-table;

$*RED-DB.when: :once, :return[{:1a}], "insert into ble ( a ) values ( 1 )";
Ble.^create: :1a;

$*RED-DB.verify;
