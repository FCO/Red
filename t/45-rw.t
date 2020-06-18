use Test;
use Red:api<2>;

model Bla {
    has $!id is serial;
    has $.a  is column is rw
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

Bla.^create-table;

my $bla = Bla.^create: :0a;

for ^10 {
    $bla.a = $_;
    $bla.^save;
    is $bla.a, $_;
    is Bla.^all.head.a, $_
}

done-testing;
