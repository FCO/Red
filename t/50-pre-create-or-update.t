use Test;

lives-ok {
    use Red:api<2>;

    model Reputation is table<reputation> is rw is export {
        has Int $.guild-id          is id;
        has Int $.user-id           is id;
        has Int $.reputation        is column;
        has DateTime $.last-updated is column = DateTime.now;
    }

    my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
    my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
    my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
    my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
    my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
    my $driver              = @conf.shift;
    my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

    schema(Reputation).create;

    .elems ?? .map(*.reputation++).save !! .create: :1reputation with Reputation.^all.grep({ .guild-id == 10 && .user-id == 6 });
    .elems ?? .map(*.reputation++).save !! .create: :1reputation with Reputation.^all.grep({ .guild-id == 10 && .user-id == 6 });
}

done-testing;
