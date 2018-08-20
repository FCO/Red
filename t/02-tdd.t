use Test;

use-ok "Red";

use Red;
use Red::ResultSeq;

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
    .a(:clean) = 13;
    is .a, 13;
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

    use Red::AST;
    my $a = 42;
    is
        (.a == 42).perl,
        Red::AST.new(:op(Red::Op::eq), :args(Red::AST.new(:op(Red::Op::cast), :args("num", .a)), 42), :bind()).perl
    ;
    is
        (42 == .a).perl,
        Red::AST.new(:op(Red::Op::eq), :args(42, Red::AST.new(:op(Red::Op::cast), :args("num", .a))), :bind()).perl
    ;
    is
        (.a == $a).perl,
        Red::AST.new(:op(Red::Op::eq), :args(Red::AST.new(:op(Red::Op::cast), :args("num", .a)), * ), :bind(42,)).perl
    ;
    is
        ($a == .a).perl,
        Red::AST.new(:op(Red::Op::eq), :args(*,  Red::AST.new(:op(Red::Op::cast), :args("num", .a))), :bind(42,)).perl
    ;

    is
        (.a != 42).perl,
        Red::AST.new(:op(Red::Op::ne), :args(Red::AST.new(:op(Red::Op::cast), :args("num", .a)), 42), :bind()).perl
    ;
    is
        (42 != .a).perl,
        Red::AST.new(:op(Red::Op::ne), :args(42, Red::AST.new(:op(Red::Op::cast), :args("num", .a))), :bind()).perl
    ;
    is
        (.a != $a).perl,
        Red::AST.new(:op(Red::Op::ne), :args(Red::AST.new(:op(Red::Op::cast), :args("num", .a)), * ), :bind(42,)).perl
    ;
    is
        ($a != .a).perl,
        Red::AST.new(:op(Red::Op::ne), :args(*,  Red::AST.new(:op(Red::Op::cast), :args("num", .a))), :bind(42,)).perl
    ;


    my $b = "loren ipsum";
    is
        (.a eq "loren ipsum").perl,
        Red::AST.new(:op(Red::Op::eq), :args(Red::AST.new(:op(Red::Op::cast), :args("str", .a)), "loren ipsum"), :bind()).perl
    ;
    is
        ("loren ipsum" eq .a).perl,
        Red::AST.new(:op(Red::Op::eq), :args("loren ipsum", Red::AST.new(:op(Red::Op::cast), :args("str", .a))), :bind()).perl
    ;
    is
        (.a eq $b).perl,
        Red::AST.new(:op(Red::Op::eq), :args(Red::AST.new(:op(Red::Op::cast), :args("str", .a)), * ), :bind("loren ipsum",)).perl
    ;
    is
        ($b eq .a).perl,
        Red::AST.new(:op(Red::Op::eq), :args(*,  Red::AST.new(:op(Red::Op::cast), :args("str", .a))), :bind("loren ipsum",)).perl
    ;

    is
        (.a ne "loren ipsum").perl,
        Red::AST.new(:op(Red::Op::ne), :args(Red::AST.new(:op(Red::Op::cast), :args("str", .a)), "loren ipsum"), :bind()).perl
    ;
    is
        ("loren ipsum" ne .a).perl,
        Red::AST.new(:op(Red::Op::ne), :args("loren ipsum", Red::AST.new(:op(Red::Op::cast), :args("str", .a))), :bind()).perl
    ;
    is
        (.a ne $b).perl,
        Red::AST.new(:op(Red::Op::ne), :args(Red::AST.new(:op(Red::Op::cast), :args("str", .a)), * ), :bind("loren ipsum",)).perl
    ;
    is
        ($b ne .a).perl,
        Red::AST.new(:op(Red::Op::ne), :args(*,  Red::AST.new(:op(Red::Op::cast), :args("str", .a))), :bind("loren ipsum",)).perl
    ;
}

given model A {} {
    isa-ok .^rs, Red::DefaultResultSeq;
}

class B::ResultSeq does Red::ResultSeq { has $.works = True }
given model B {} {
    isa-ok .^rs, B::ResultSeq;
    ok .^rs.works;
}

class MyResultSet does Red::ResultSeq {has $.is-it-custom = True}
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
    class B::ResultSeq {}
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
    has Int     $.author-id is column{ :references{ Person.id } };
    has Person  $.author    = .^relates: { .id == $!author-id };
}

model Person {
    has Int             $.id    is column{ :id };
    has Post::ResultSeq $.posts = .^relates: { .author-id == $!id };
}

is Post.^id>>.name, < $!id >;
is Post.new(:42id).^id-values, < 42 >;

isa-ok Person.new(:42id).posts, Post::ResultSeq;
isa-ok Post.new(:123author-id).author, Person;

model Person2 { ... }

model Post2 {
    has Int      $.id        is column{ :id };
    has Int      $.author-id is referencing{ Person2.id };
    has Person2  $.author    is relationship{ .author-id };
}

model Person2 {
    has Int     $.id    is column{ :id };
    has Post2   @.posts is relationship{ .author-id };
}

say Post2.new.author;

my $alias1 = Post2.^alias;
is $alias1.^name,                   "Post2_1";
is $alias1,                         $alias1.id.class;
is Post2,                           Post2.id.class;

is $alias1.id.attr,                 Post2.id.attr;
is $alias1.id.attr-name,            Post2.id.attr-name;
is $alias1.id.id,                   Post2.id.id;
is $alias1.id.references,           Post2.id.references;
is $alias1.id.nullable,             Post2.id.nullable;
is $alias1.id.name,                 Post2.id.name;

is $alias1,                         $alias1.author-id.class;
is Post2,                           Post2.author-id.class;

is $alias1.author-id.attr,          Post2.author-id.attr;
is $alias1.author-id.attr-name,     Post2.author-id.attr-name;
is $alias1.author-id.id,            Post2.author-id.id;
is $alias1.author-id.references,    Post2.author-id.references;
is $alias1.author-id.nullable,      Post2.author-id.nullable;
is $alias1.author-id.name,          Post2.author-id.name;

my $alias2 = Post2.^alias: "me";
is $alias2.^name,                   "me";
is $alias2,                         $alias2.id.class;
is Post2,                           Post2.id.class;

is $alias2.id.attr,                 Post2.id.attr;
is $alias2.id.attr-name,            Post2.id.attr-name;
is $alias2.id.id,                   Post2.id.id;
is $alias2.id.references,           Post2.id.references;
is $alias2.id.nullable,             Post2.id.nullable;
is $alias2.id.name,                 Post2.id.name;

is $alias2,                         $alias2.author-id.class;
is Post2,                           Post2.author-id.class;

is $alias2.author-id.attr,          Post2.author-id.attr;
is $alias2.author-id.attr-name,     Post2.author-id.attr-name;
is $alias2.author-id.id,            Post2.author-id.id;
is $alias2.author-id.references,    Post2.author-id.references;
is $alias2.author-id.nullable,      Post2.author-id.nullable;
is $alias2.author-id.name,          Post2.author-id.name;

is $alias1.^name,                   "Post2_1";
is Post2.^name,                     "Post2";

#is Post2.where({ .id == 42 }).query.perl, 42;

is Post2.author-id.as("bla").name, "bla";
is Post2.author-id.as("bla").attr-name, "bla";
ok not Post2.author-id.as("bla").id;
ok Post2.author-id.as("bla").nullable;
ok not Post2.author-id.as("bla", :!nullable).nullable;

#say (Post2.id == 42).tables;
#say (Post2.author-id == Person2.id).tables;
#is (Post2.id == 42).tables.elems, 1;
#is (Post2.author-id == Person2.id).tables.elems, 2;

given model { has $.a is column{ :unique }; has $.b is column; ::?CLASS.^add-unique-constraint: { .a, .b } } {
    is .^constraints<unique>.elems, 2;
}

done-testing
