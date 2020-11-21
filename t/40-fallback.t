use Test;
use Red:api<2>;

model Bla {
    has UInt $.id    is serial;
    has $.value is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
red-defaults default    => database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Bla).drop;
Bla.^create-table;

Bla.^create(:value("value-{$_}")) for ^5;

my @tests =
    %(
        :code{ .map: -> $a, $b? { quietly "{ $a.value }-{ $b.?value }" } },
        :expected<value-0-value-1 value-2-value-3 value-4->,
        :error-message("Count bigger than 1"),
    ),
    %(
        :code{ .map: { print .value; .value } },
        :expected<value-0 value-1 value-2 value-3 value-4>,
        :error-message("Trying to print inside the map's block"),
    ),
    %(
        :code{ .grep: { print .value; .id %% 2 } },
        :expected((2, 4).map: { Bla.new: :id($_), :value("value-{ $_ - 1 }") }),
        :error-message("Trying to print inside the grep's block"),
    ),
;

subtest {
    for @tests -> (:&code!, :@expected!, :$error-message) {
        my $*RED-FALLBACK = True;
        my $*OUT = class :: { method print(|) {} }

        lives-ok {
            is-deeply code(Bla.^all).Seq, @expected.Seq;
        }
    }
}

subtest {
    for @tests -> (:&code!, :@expected!, Str :$error-message) {
        my $*RED-FALLBACK = False;

        dies-ok { code(Bla.^all).Seq }, $error-message;
    }
}

done-testing;
