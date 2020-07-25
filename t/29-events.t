use Test;
use Red;
use Red::AST::CreateTable;
use Red::AST::Insert;

plan 18;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

isa-ok Red.events, Supply;

model Bla { has UInt $.id is serial; has Str $.name is column }
schema(Bla).drop;

my $s = start react whenever Red.events -> $event {
    given ++$ {
        when 1 {
            is $event.data, 42;
            is-deeply $event.metadata, {};
            is-deeply $event.db, $*RED-DB;
            with %*ENV<RED_DATABASE> {
                skip "It's not using SQLite"
            } else {
                is $event.db-name, "Red::Driver::SQLite";
            }
        }
        when 2 {
            is $event.data, 42;
            is-deeply $event.metadata, {:bla<ble>}
            is-deeply $event.db, $*RED-DB;
            with %*ENV<RED_DATABASE> {
                skip "It's not using SQLite"
            } else {
                is $event.db-name, "Red::Driver::SQLite";
            }
        }
        when 3 {
            isa-ok $event.data, Red::AST::CreateTable;
            is-deeply $event.metadata, {:bla<ble>}
            is-deeply $event.db, $*RED-DB;
            with %*ENV<RED_DATABASE> {
                skip "It's not using SQLite"
            } else {
                is $event.db-name, "Red::Driver::SQLite";
            }
        }
        when 4 {
            isa-ok $event.data, Red::AST::Insert;
            is-deeply $event.metadata, {:bla<ble>}
            is-deeply $event.db, $*RED-DB;
            with %*ENV<RED_DATABASE> {
                skip "It's not using SQLite"
            } else {
                is $event.db-name, "Red::Driver::SQLite";
            }
        }
        default {
            is-deeply $event.metadata, {:bli<blo>}
            done
        }
    }
}
sleep 1;

Red.emit: 42;

my %*RED-METADATA = bla => "ble";
Red.emit: 42;

Bla.^create-table;

Bla.^create: :name<bla>;

{
    my %*RED-METADATA = bli => "blo";
    Red.emit;
}
await $s;
