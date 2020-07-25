use Red;
use Test;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

model M is table<mmm> {
    has Int $.a is column is rw
}

schema(M).drop;

M.^create-table;

M.^create: :1a;
M.^create: :2a;
M.^create: :3a;
M.^create: :4a;
M.^create: :5a;

M.^all.grep(*.a > 3).map({ .a = 42 }).save;

is M.^all.map(*.a), (1, 2, 3, 42, 42);

done-testing
