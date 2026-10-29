use Test;
use Red;

enum Bla <a e i o u>;

model TestModel {
    has     $.id    is serial;
    has Bla $.enum  is column{ :type<integer>, };
    has     @.array-col is column{ :type<varchar>, :inflate{ .split(',')».Int.Array }, :deflate{ .join: ',' } };
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(TestModel).drop;
TestModel.^create-table;

lives-ok {
    TestModel.^create: :enum(a), :array-col[1, 2, 3, 4, 5];
    my %data := $*RED-DB.execute("select * from test_model where enum = 0").row;
    is %data<enum>,  0;
    is %data<array_col>, "1,2,3,4,5";
    my $obj = TestModel.^all.head;
    isa-ok    $obj.enum,  Bla::a;
    is-deeply $obj.array-col, [1, 2, 3, 4, 5];
}, "Deflator and inflator don't die";

done-testing;
