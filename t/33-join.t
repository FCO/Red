use Test;
use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

model Bla { has $!id is serial; has Int $.ble is column }
model Ble { has $!id is serial; has Int $.bla is column }

Bla.^create-table;
Ble.^create-table;

Bla.^create: :ble($_) for ^10;
Ble.^create: :bla($_) for ^10;

is Bla.^all.grep(-> $bla {
    Ble.^alias("test", :base($bla), :relationship{.bla == $bla.ble}).bla == 3
}).Seq>>.ble, < 3 >;

is Bla.^join(Ble, *.ble == *.bla).^all.map(*.bla), ^10;

is Bla.^join(:name<test>, Ble, *.ble == *.bla).^all.map(*.bla), ^10;

done-testing;
