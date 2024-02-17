#!/ust/bin/env raku

use Red;
use Test;

model Bla {
   has     $.id is serial;
   has     @.no-type is column;
   has Str @.str is column;
   has Int @.int is column;
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Bla).drop;
Bla.^create-table;

Bla.^create: :no-type(<a b c>), :str(Array[Str].new: <x y z>), :int(Array[Int].new: [1, 2, 3]);

lives-ok {
    my $obj = Bla.^all.first;

    is $obj.no-type, <a b c>;
    isa-ok $obj.str, Array[Str];
    is $obj.str, <x y z>;
    isa-ok $obj.int, Array[Int];
    is $obj.int, [1, 2, 3];
}

done-testing
