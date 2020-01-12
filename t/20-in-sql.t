use Red;
use Test;

model Foo is rw {
    has Int $.id    is serial;
    has Str $.name  is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

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


# Raw RS
is-deeply Foo.^rs.grep( *.id in Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset";
is-deeply Foo.^rs.grep( *.id (<) Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset with (<) operator ";
is-deeply Foo.^rs.grep( *.id ⊂ Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset with ⊂ operator";

is-deeply Foo.^rs.grep( not *.id in Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[1],  ), "not in with resultset";
is-deeply Foo.^rs.grep( not *.id (<) Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[1],  ), "not in with resultset with (<) operator";
is-deeply Foo.^rs.grep( not *.id ⊂ Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[1],  ), "not in with resultset with ⊂ operator";
is-deeply Foo.^rs.grep( *.id (>) Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[1],  ), "not in with resultset with (>) operator";
is-deeply Foo.^rs.grep( *.id ⊃ Foo.^rs.grep( { .name ne 'b' } ).map({ .id })  ).Seq, ( @foos[1],  ), "not in with resultset with ⊃ operator";

# AST
is-deeply Foo.^rs.grep( *.id in Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset AST ";
is-deeply Foo.^rs.grep( *.id (<) Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset  AST with (<) operator ";
is-deeply Foo.^rs.grep( *.id ⊂ Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[0], @foos[2], @foos[3]), "in with resultset  AST with ⊂ operator";

is-deeply Foo.^rs.grep( not *.id in Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset AST ";
is-deeply Foo.^rs.grep( not *.id (<) Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset  AST with (<) operator";
is-deeply Foo.^rs.grep( not *.id ⊂ Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset  AST with ⊂ operator";
is-deeply Foo.^rs.grep( *.id (>) Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset  AST with (>) operator";
is-deeply Foo.^rs.grep( *.id ⊃ Foo.^rs.grep( { .name ne 'b' } ).map({ .id }).ast  ).Seq, ( @foos[1],  ), "not in with resultset  AST with ⊃ operator";


model MultiBar {
    has Int $.id is serial;
    has Str $.name is column;
}

model MultiFoo {
    has Int $.id is serial;
    has Str $.name is column;
    has Int $.bar-id is referencing( *.id, :model<MultiBar> );
    has MultiBar $.bar is relationship( { .bar-id });
}

MultiBar.^create-table;
MultiFoo.^create-table;


my @multibars;

for <one two three four> -> $name {
    @multibars.append: MultiBar.^create(:$name);
}

my @multifoos;

for @multibars -> $bar {
    @multifoos.append: MultiFoo.^create(:$bar, name => $bar.name ~ '-foo');
}

is-deeply MultiFoo.^rs.grep(*.bar-id in MultiBar.^rs.grep( *.name eq 'one' ).map( *.id ) ).Seq, (@multifoos[0], ), "in with different table in sub-select (no cartesian join)";

done-testing;
# vim: ft=perl6
