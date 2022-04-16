use Red;
use Test;

model Foo is rw {
    has Int $.id    is serial;
    has Str $.name  is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG-AST>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(Foo).drop;
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

schema(MultiBar, MultiFoo).drop;
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

todo "What's happening here???" with %*ENV<RED_DATABASE>;
is-deeply MultiFoo.^rs.grep(*.bar-id in MultiBar.^rs.grep( *.name eq 'one' ).map( *.id ) ).Seq, (@multifoos[0], ), "in with different table in sub-select (no cartesian join)";

subtest "#521" => {
    model A {
        has Str $.id is id;
        has     @.bs is relationship({ .a-id }, model => "B" );
    }

    model B {
        has Int  $.id   is serial;
        has Str  $.a-id is column({ name => "a", model-name => "A", column-name => "id" });
        has      $.a    is relationship({ .a-id }, model => "A");
        has Int  $.c-id is referencing(model => "C", column => "id" );
        has      $.c    is relationship({ .c-id }, model => "C");
        has Bool $.d    is column is rw = True;
    }

    model C {
        has Int $.id is serial;
        has Str $.d  is column;
        has     @.bs is relationship({ .c-id }, model => "B" );
    }

    A.^create-table: :if-not-exists;
    C.^create-table: :if-not-exists;
    B.^create-table: :if-not-exists;

    B.^all.delete;
    C.^all.delete;
    A.^all.delete;

    B.^all.delete;
    C.^all.delete;
    A.^all.delete;

    my $a = A.^create( :id<FOO>, :bs[{ :c{ :d<a> }, :!d }, { :c{ :d<b> }, :!d }, { :c{ :d<c> }, :!d }, { :c{ :d<d> }, :!d }, ] );

    is B.^all.grep({ not .d }).map(*.c.d).Seq, <a b c d>;

    lives-ok {
        my $sub = $a.bs.grep( *.c.d ⊂ <a b c> ).map( *.id );
        $a.bs.grep(*.id ⊂ $sub).map({ .d = True }).save;
    }

    is B.^all.grep({ so .d }).map(*.c.d).Seq, <a b c>;

    lives-ok {
        $a.bs.grep(*.c.d ⊂ <a b c>).map({ .d = False }).save;
    }

    is B.^all.grep({ not .d }).map(*.c.d).Seq, <a b c d>
}

done-testing;
# vim: ft=raku
