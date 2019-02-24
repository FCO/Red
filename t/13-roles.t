use Test;
use Red;
use Red::Column;

my $*RED-DB = database "Mock";
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
$*RED-DB.die-on-unexpected;

role Bla { has Str $.a is column }

model Ble does Bla {}

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    CREATE TABLE ble(
        a varchar(255) NOT NULL
    )
EOSQL

Ble.^create-table;

model Bli does Bla { has Str $.b is column }

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    CREATE TABLE bli(
        a varchar(255) NOT NULL,
        b varchar(255) NOT NULL
    )
EOSQL

Bli.^create-table;

$*RED-DB.when: :once, :return[{:1a}], "insert into ble ( a ) values ( ? )";
Ble.^create: :1a;

role SerialId {
    has UInt $!id is serial;
}

model Blu  { ... }

model Blo does SerialId {
    has UInt $!blu-id is referencing{ Blu.id };
    has Blu  $.blu    is relationship{ .blu-id };
}

model Blu does SerialId {
    has Blo @.blo is relationship{ .blu-id };
}

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    create table blo (
        blu_id integer null references blu (id),
        id integer not null primary key autoincrement
    )
EOSQL

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    create table blu (
        id integer not null primary key autoincrement
    )
EOSQL

Blo.^create-table;
Blu.^create-table;

$*RED-DB.when: :once, :return[{:1id}], "insert into blu default values";
$*RED-DB.when: :once, :return[{:1id, :1blu-id},], "insert into blo( blu_id )values( ? )";

my $blu = Blu.^create;
my $blo = $blu.blo.create;

$*RED-DB.when: :3times, :return[{:1id}], "select blu.id from blu where blu.id = ?";

isa-ok $blu, Blu;
isa-ok $blo, Blo;

is-deeply $blo.blu, $blu;

$*RED-DB.verify;

isa-ok Ble.a, Red::Column;
isa-ok Bli.a, Red::Column;
isa-ok Bli.b, Red::Column;

done-testing
