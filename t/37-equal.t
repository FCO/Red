use Test;
use Red;

model Bla { has $.id is serial; has Int $.bla is column }
model Ble { has $.id is serial; has Int $.ble is column }

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Bla, Ble).create;

Bla.^create: :bla($_) for ^50;
Ble.^create: :ble($_) for ^50;

my @bla = Bla.^all; # running the query now, use := to not run the query
my @ble = Ble.^all; # running the query now, use := to not run the query

my @tests =
        *.head,
        *.head(5),
        *.head(*-5),
        *.tail(5),
        *.tail(*-5),
        *.map(*.bla),
        *.grep(*.bla > 5),
        *.grep(*.id > 5).map(*.bla),
        *.grep(*.id  %% 2).map(*.bla ~ "bla"),
        *.grep(*.bla %% 2).map(*.bla div 2),
        *.first,
        *.first(*.bla %% 5),
        *.sort(*.bla),
        *.sort(-*.bla),
        *.sort({ .bla %% 5, .bla }),
        *.sort({ .bla %% 5, .bla }).map(*.bla),
        *.map({ .bla > 10 ?? "bla" !! "ble" }),
        *.map({ .bla > 10 ?? .id !! .bla }),
        *.map({ .bla > 10 ?? .id ~ "id" !! .bla ~ "bla" }),
        *.grep(*.bla %% 2).map(*.bla * 2),
        *.grep(*.id  %% 2).map(*.bla * 2),
        *.grep(*.id  %% 2).map(*.bla + 5),
        *.grep(*.id  %% 2).map(*.bla - 5),
;

my @todo =
        *.grep(*.id  %% 2).map(*.bla * 2.1),
        *.grep(*.id  %% 2).map(*.bla + 5.1),
        *.grep(*.id  %% 2).map(*.bla - 5.1),
        *.map({ "bla" if .bla > 45 }),
        *.map({ next unless .bla < 5; "bla" }),
;

my $*RED-FALLBACK = False;
lives-ok {
        is-deeply .(Bla.^all).Seq, .(@bla).Seq for @tests;
}

#lives-ok {
#        todo "NYI";
#        is-deeply .(Bla.^all).Seq, .(@bla).Seq for @todo;
#}

done-testing;
