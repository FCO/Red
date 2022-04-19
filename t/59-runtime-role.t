#!/usr/bin/env raku

use Test;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;
use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

subtest {

    my role FooMixin {
        method zub() {
        }
    }


    model BarMixin {
        has Int $.id is serial;
    }

    BarMixin.^create-table;

    my $bar = BarMixin.^create;

    my $bar-id = $bar.id;

    lives-ok { $bar.^mixin(FooMixin) }, '^mixin lived';

    does-ok $bar,FooMixin, 'role got applied';

    lives-ok { is $bar.id, $bar-id, "id is correct" }, "get attribute lives";
}, "runtime add role to row with '^mixin'";

subtest {

    my role FooDoes {
        method zub() {
        }
    }


    model BarDoes {
        has Int $.id is serial;
    }

    BarDoes.^create-table;

    my $bar = BarDoes.^create;

    my $bar-id = $bar.id;

    lives-ok { $bar does FooDoes }, 'does lived';

    does-ok $bar,FooDoes, 'role got applied';

    lives-ok { is $bar.id, $bar-id, "id is correct" }, "get attribute lives";
}, "runtime add role to row with 'does'";

done-testing();
# vim: ft=raku
