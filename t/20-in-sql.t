use Red;
use Test;

model Foo is rw {
    has Int $.id    is serial;
    has Str $.name  is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

Foo.^create-table;

my @foos;
for <a b c d> -> $name {
    @foos.append: Foo.^create(:$name);
}

is-deeply Foo.^rs.grep(*.name in <b c>).Seq, (@foos[1], @foos[2]), "in with literal list";
is-deeply Foo.^rs.grep(*.name (<) <b c>).Seq, (@foos[1], @foos[2]), "in with literal list with (<) operator";
is-deeply Foo.^rs.grep(*.name ⊂ <b c>).Seq, (@foos[1], @foos[2]), "in with literal list with ⊂";

is-deeply Foo.^rs.grep(not *.name in <b c>).Seq, ( @foos[0], @foos[3]), "not in with literal list";
is-deeply Foo.^rs.grep(not *.name (<) <b c>).Seq, ( @foos[0], @foos[3]), "not in with literal list with (<) operator";
is-deeply Foo.^rs.grep(not *.name ⊂ <b c>).Seq, ( @foos[0], @foos[3]), "not in with literal list with ⊂ operator";
is-deeply Foo.^rs.grep(*.name ⊃ <b c>).Seq, ( @foos[0], @foos[3]), "not in with literal list with ⊃ operator";
is-deeply Foo.^rs.grep( *.name (>) <b c>).Seq, ( @foos[0], @foos[3]), "not in with literal list with (>) operator";


is-deeply Foo.^rs.grep( *.id in Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset";
is-deeply Foo.^rs.grep( *.id (<) Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset with (<) operator ";
is-deeply Foo.^rs.grep( *.id ⊂ Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset with ⊂ operator";

is-deeply Foo.^rs.grep( not *.id in Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset";
is-deeply Foo.^rs.grep( not *.id (<) Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset with (<) operator";
is-deeply Foo.^rs.grep( not *.id ⊂ Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset with ⊂ operator";
is-deeply Foo.^rs.grep( *.id (>) Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset with (>) operator";
is-deeply Foo.^rs.grep( *.id ⊃ Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset with ⊃ operator";

done-testing;
# vim: ft=perl6
