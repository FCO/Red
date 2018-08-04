use Test;

use-ok "Red";

use Red;

#isa-ok model {}.HOW, MetamodelX::ResultSource;

can-ok model {}.HOW, "columns";
can-ok model {}.HOW, "is-dirty";
can-ok model {}.HOW, "clean-up";
can-ok model {}.HOW, "dirty-columns";

given model { has $!a is column }.new: :42a {
    ok .^is-dirty;
    is .^dirty-columns.keys.sort, < $!a >;
    .^clean-up;
    ok not .^is-dirty;
    dies-ok { .a };
}

given model { has $.a is column }.new: :42a {
    ok .^is-dirty;
    is .^dirty-columns.keys.sort, < $!a >;
    .^clean-up;
    ok not .^is-dirty;
    is .a, 42;
    dies-ok { .a = 42 };
    ok not .^is-dirty;
}

given model { has $.a is rw is column }.new {
    ok .^is-dirty;
    is .^dirty-columns.keys.sort, < $!a >;
    .^clean-up;
    ok not .^is-dirty;
    .a = 42;
    is .a, 42;
    ok .^is-dirty;
    is .^dirty-columns.keys.sort, < $!a >;
    .^clean-up;
    ok not .^is-dirty;
}

given model { has $.a is rw is column; has $.b is rw is column }.new {
    ok .^is-dirty;
    is .^dirty-columns.keys.sort, < $!a $!b >;
    .^clean-up;
    ok not .^is-dirty;
    .a = 42;
    is .a, 42;
    ok .^is-dirty;
    is .^dirty-columns.keys.sort, < $!a >;
    .b = 13;
    is .b, 13;
    is .^dirty-columns.keys.sort, < $!a $!b >;
    .^clean-up;
    ok not .^is-dirty;
}

given model {
    has $.a is column;
    has $!b is column;
    has $!c is column{:id, :name<column_c>, :!null};
} {
    use Red::Column;
    isa-ok .a, Red::Column;
    is .a.name, "a";
    isa-ok .b, Red::Column;
    is .b.name, "b";
    isa-ok .c, Red::Column;
    is .c.name, "column_c";
    ok .c.id;
    ok not .c.null;
}

done-testing
