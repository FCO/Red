use Test;

use-ok "Red";

use Red;
use Red::ResultSet;

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
    has $!c is column{:id, :name<column_c>, :!nullable};
} {
    use Red::Column;
    isa-ok .a, Red::Column;
    is .a.name, "a";
    isa-ok .b, Red::Column;
    is .b.name, "b";
    isa-ok .c, Red::Column;
    is .c.name, "column_c";
    ok .c.id;
    ok not .c.nullable;

    my $a = 42;
    is (.a == 42).WHICH, Red::Filter.new(:op(Red::Op::eq), :args(.a, 42)  :bind(    )  ).WHICH;
    is (42 == .a).WHICH, Red::Filter.new(:op(Red::Op::eq), :args(42, .a)  :bind(    )  ).WHICH;
    is (.a == $a).WHICH, Red::Filter.new(:op(Red::Op::eq), :args(.a, * ), :bind(42, )  ).WHICH;
    is ($a == .a).WHICH, Red::Filter.new(:op(Red::Op::eq), :args(*,  .a), :bind(42, )  ).WHICH;

    is (.a != 42).WHICH, Red::Filter.new(:op(Red::Op::ne), :args(.a, 42)  :bind(    )  ).WHICH;
    is (42 != .a).WHICH, Red::Filter.new(:op(Red::Op::ne), :args(42, .a)  :bind(    )  ).WHICH;
    is (.a != $a).WHICH, Red::Filter.new(:op(Red::Op::ne), :args(.a, * ), :bind(42, )  ).WHICH;
    is ($a != .a).WHICH, Red::Filter.new(:op(Red::Op::ne), :args(*,  .a), :bind(42, )  ).WHICH;
}

given model A {} {
    isa-ok .^rs, Red::DefaultResultSet;
}

class B::ResultSet does Red::ResultSet { has $.works = True }
given model B {} {
    isa-ok .^rs, B::ResultSet;
    ok .^rs.works;
}

class MyResultSet does Red::ResultSet {has $.is-it-custom = True}
given model C is rs-class(MyResultSet) {} {
    isa-ok .^rs, MyResultSet;
    ok .^rs.is-it-custom
}

given model D is rs-class<MyResultSet> {} {
    isa-ok .^rs, MyResultSet;
    ok .^rs.is-it-custom
}

#`{{{
eval-lives-ok q[
    use Red;
    class B::ResultSet {}
    model B {}
];

eval-lives-ok q[
    class MyResultSet {}
    model C is rs-class(MyResultSet) {}
];

eval-lives-ok q[
    class MyResultSet {}
    model D is rs-class<MyResultSet> {}
];
}}}

given model BlaBleBli {} {
    is .^table, "bla_ble_bli";
}

given model BlaBleBli2 is table<not_that> {} {
    is .^table, "not_that";
}

#model TestDate {
#    has $.date is query('select now()');
#}
#
#ok now < TestDate.new.date < now;

model Person { ... }

model Post {
    has Int     $.id        is column{ :id };
    has Int     $.author-id is column;
    has Person  $.author    = .where: .id == $!author-id;
}

model Person {
    has Int             $.id    is column{ :id };
    has Post::ResultSet $.posts = .where: .of.author-id == $!id;
}

is Post.^id>>.name, < $!id >;
is Post.new(:42id).^id-values, < 42 >;

isa-ok Person.new(:42id).posts, Post::ResultSet;
isa-ok Post.new(:123author-id).author, Person;

    ok False;
done-testing
