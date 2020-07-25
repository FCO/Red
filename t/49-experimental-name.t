use Test;
use Red <shortname>;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model A::B::C::D::EFG {
    has $!id is serial
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

is A::B::C::D::EFG.^table, "e_f_g";

lives-ok {
    A::B::C::D::EFG.^create-table
}

done-testing;
