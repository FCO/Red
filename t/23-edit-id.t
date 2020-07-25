use Red;
use Test;

model MyModel {
    has Str $.name is id is rw;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(MyModel).drop;
MyModel.^create-table: :if-not-exists;

my $m = MyModel.^create: name => "a name";
is $m.name, "a name";
$m.name = "changed name";
is $m.name, "changed name";
$m.^save;
is $m.name, "changed name";
my $m2 = MyModel.^load: name => "changed name";
ok $m2;
is $m2.name, "changed name";
$m.name = "another name";
$m.^save;
is $m.name, "another name";
is MyModel.^load(name => "another name").?name, "another name";

done-testing;
