use Test;
use Red;
use LibUUID;

model Transaction is table<transactions> {
    has UInt    $.id            is serial;
    has Bool    $.closed        is column = False;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

Transaction.^create-table;

Transaction.^create;
Transaction.^create: :closed;

is Transaction.^all.sort(*.id).Seq.map(*.closed), (False, True);
is Transaction.^all.sort(*.id).map(*.closed), (False, True);
is Transaction.^all.sort(*.id).map(!*.closed), (True, False);

done-testing;
