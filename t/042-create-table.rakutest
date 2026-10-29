use Test;
use Red:api<2>;

model Mmm {
    has $!id    is serial;
    has $.value is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
red-defaults default    => database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Mmm).drop;

lives-ok { Mmm.^create-table }
dies-ok  { Mmm.^create-table }
lives-ok { Mmm.^create-table: :if-not-exists }
lives-ok { Mmm.^create-table: :unless-exists }

done-testing;
