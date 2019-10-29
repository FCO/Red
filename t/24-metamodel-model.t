use Test;
my $*RED-DB = database "SQLite";

use-ok "Red";

use Red;

model Bla {
    has Str $.column is column;
}

Bla.^create-table;

is Bla.^column-names, < column >;

is model :: { has $.a is column; has $.b is column; has $.c is column<d> }.^column-names, <a b d>;

# TODO: fix
#is-deeply model :: {
#    has $.a is column{ :unique };
#    has $.b is column{ :unique };
#    has $.c is column{ :unique, :name<d> }
#}.^constraints>>.name, <a b d>;

model Ble:ver<1.2.3> is table<not-ble> is nullable {
    has $.a is referencing{ ::?CLASS.b }
    has $.b is referencing{ ::?CLASS.c }
    has $.c is column{:references{ ::?CLASS.a }, :name<d>}
    has $.e is referencing{:model<Bla>, :column<column>}
}

is-deeply Ble.^references.keys.Set, set < a b c e >;
is-deeply Ble.^references.values>>.name.Set, set < a b d e >;

is-deeply Ble.^references.values.map(*.ref().attr.package.^table).Set, set < bla not-ble >;
is-deeply Ble.^references.values.map(*.ref().name).Set, set < column a b d >;

is Bla.^table, "bla";
is Ble.^table, "not-ble";
is model :: is table<bli> {}.^table, "bli";

is Bla.^as, "bla";
is Ble.^as, "not-ble";
is model :: is table<bli> {}.^as, "bli";

is Bla.^alias("not-bla").^as, "not_bla";
is Ble.^alias("not-not-ble").^as, "not_not_ble";
is model :: is table<bli> {}.^alias("not-bli").^as, "not_bli";

is Bla.^alias("not-bla").^orig, Bla;
is Ble.^alias("not-not-ble").^orig, Ble;

is Bla.^rs-class-name, "Bla::ResultSeq";
is Ble.^rs-class-name, "Ble::ResultSeq";

is-deeply Bla.^columns>>.name.Set, set < $!column >;
is-deeply Ble.^columns>>.name.Set, set < $!a $!b $!c $!e >;

is Bla.^migration-hash<columns>.elems, 1;
is Bla.^migration-hash<name>, "bla";
is Bla.^migration-hash<version>, v0;

is Ble.^migration-hash<columns>.elems, 4;
is Ble.^migration-hash<name>, "not-ble";
is Ble.^migration-hash<version>, v1.2.3;

is-deeply model :: {}.new.^id-values, ();
is-deeply model :: { has $.id is id }.new(:42id).^id-values, (42,);
is-deeply model :: { has $.id1 is id; has $!id2 is id = 13 }.new(:42id1).^id-values, (42, 13);

todo "default-nullable returning false by default";
ok not Bla.^default-nullable;
ok Ble.^default-nullable;

is-deeply model :: { has Int $.a is column{ :unique } }.^unique-constraints>>.name, (('$!a',),);

is-deeply Bla.^attr-to-column, %('$!column' => "column");
is-deeply Ble.^attr-to-column, %('$!a' => "a", '$!b' => "b", '$!c' => "d", '$!e' => "e");


is Bla.^rs, Bla.^all;

model MyModel { ... }

MyModel.^create-table;

use Red::ResultSeq;
class MyRS does Red::ResultSeq[MyModel] {
    method answer { 42 }
}
my $rs = model MyModel is rs-class<MyRS> { has Str $.a is column }.^rs;
isa-ok $rs, MyRS;
does-ok $rs, Red::ResultSeq;

can-ok $rs, "answer";
is $rs.answer, 42;

can-ok $rs.grep({ .a }), "answer";
is $rs.grep({ .a }).answer, 42;

ok model :: is table<t1> { has Str $.bla is column }.^create-table;
ok model :: is table<t2> { has Str $.bla is column }.^create-table: :if-not-exists;
ok model :: is table<t3> { has Str $.bla is column }.^create-table: :unless-exists;

model IsId { has UInt $.id is id; has Str $.not-id is column{ :unique }; has Str $.col is column }

dies-ok { Bla.^new-with-id(42) };
is-deeply IsId.^new-with-id(42), IsId.new: :42id;

is-deeply IsId.^id>>.name, ('$!id',);

ok IsId.^is-id: IsId.^attributes.head;
ok not IsId.^is-id: IsId.^attributes.head(2).tail;

is-deeply IsId.^general-ids>>.name, ('$!id', $('$!not-id',));

my $bla = IsId.new;
$bla.^set-id: 42;
is-deeply $bla, IsId.new: :42id;
$bla.^set-id: { :13id };
is-deeply $bla, IsId.new: :13id;
$bla.^set-id: { :3id, :42not-id };
is-deeply $bla, IsId.new: :3id, :42not-id;

is-deeply $bla.^id-map(42), { :42id, };

# TODO
#my $filter = $bla.^id-filter;
#is $filter, "";

# TODO
#say IsId.^filter-id: 42;


is Bla.^table, "bla";
Bla.^table = "not_bla";
is Bla.^table, "not_bla";

ok not $bla.^is-on-db;
$bla.^saved-on-db;
ok $bla.^is-on-db;

model Tree {
    has UInt   $!id        is id;
    has Str    $.value     is column;
    has UInt   $!parent-id is referencing{ Tree.id };

    has Tree   $.parent    is relationship{ .parent-id };
    has Tree   @.kids      is relationship{ .parent-id };
}

Tree.^create-table: :if-not-exists;

Tree.^create: :value<Bla>, :parent{:value<Ble>}, :kids[{:value<Bli>}, {:value<Blo>}, {:value<Blu>}];

my $adam = Tree.^load(1);
is $adam.value, "Ble";
ok not $adam.parent.defined;
is-deeply $adam.kids>>.value, ("Bla",);
is-deeply $adam.kids>>.parent, ($adam,);
is-deeply $adam.kids>>.kids>>.value, (<Bli Blo Blu>, );
#is-deeply flat($adam.kids>>.kids>>.parent), ($adam.kids.head xx 3).head;

done-testing;
