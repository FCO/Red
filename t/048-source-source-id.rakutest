use Test;
use Red:api<2>;

#plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model Login is table<logged_user> {
    has         $.id        is serial;
    has         $.source    is column;
    has UInt    $.source-id is referencing(*.id, :model<Buyer>);
    has Instant $.created   is column = now;
}

model Buyer {
    has UInt $.id    is serial;
    has $.name  is column;
    method login {
        self.^rs.join-model: Login, -> $b, $l { $b.id == $l.source-id && $l.source eq "buyer" }
    }
}

model Seller {
    has UInt $.id    is serial;
    has $.name  is column;
    method login {
        self.^rs.join-model: Login, -> $b, $l { $b.id == $l.source-id && $l.source eq "seller" }
    }
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Login, Buyer, Seller).drop.create;

Buyer.^create:  :name($_) for <bla ble bli>;
Seller.^create: :name($_) for <sla sle sli>;

.login.create for Buyer.^all;
.login.create for Seller.^all;

is Login.^all.elems, 6;
is Login.^all.grep(*.source eq "buyer").elems, 3;
is Login.^all.grep(*.source eq "seller").elems, 3;

is Buyer.^all.head.login.elems, 1;

done-testing;
