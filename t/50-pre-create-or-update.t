use Test;

use Red:api<2>;

model Reputation is table<reputation> is rw {
    has Int      $.guild-id     is id;
    has Int      $.user-id      is id;
    has Int      $.reputation   is column;
    has DateTime $.last-updated is column .= now;
    method !update-time is before-update { self.last-updated .= now }
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Reputation).drop.create;

.elems ?? .map(*.reputation++).save !! .create: :1reputation with Reputation.^all.grep({ .guild-id == 1 && .user-id == 1 });
my $time = Reputation.^load(:1guild-id, :1user-id).last-updated;
my $rep = 1;
for ^10 {
    .elems ?? .map(*.reputation++).save !! .create: :1reputation with Reputation.^all.grep({ .guild-id == 1 && .user-id == 1 });
    my $curr = Reputation.^load(:1guild-id, :1user-id);
    my $next = $curr.last-updated;
    cmp-ok $time, "<", $next;
    is $curr.reputation, ++$rep;
    $time = $next
}

done-testing;
