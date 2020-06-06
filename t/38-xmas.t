use Test;

use Red:api<2>;
use lib <examples/xmas>;

use Child;
use Gift;
use ChildAskedOnYear;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
red-defaults default    => database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(Child, Gift, ChildAskedOnYear).create;

for <doll ball car pokemon> -> $name {
    Gift.^create: :$name;
}

Child.^create: :name<Fernanda>, :country<UK>, :asked-by-year[{:gift{:name<pokemon>}}];
Child.^create: :name<Sophia>,   :country<UK>, :asked-by-year[{:gift{:name<doll>}}];

my $*RED-FALLBACK = False;

given Child.^find(:name<Fernanda>) {
    isa-ok .asked.create(:gift{:name<ball>}), ChildAskedOnYear;
    is-deeply .asked.map(*.gift).Seq, (Gift.^load(:name<pokemon>), Gift.^load(:name<ball>)).Seq;
    is-deeply .asked.map(*.gift.name).Seq, <pokemon ball>.Seq;
}

isa-ok Child.^find(:name<Sophia>).asked.create(:gift{:name<ball>}), ChildAskedOnYear;
given Gift.^find(:name<ball>) {
    is .child-asked-on-year.elems, 2;
    is-deeply .child-asked-on-year.map(*.child).Seq, (Child.^find(:name<Fernanda>), Child.^find(:name<Sophia>)).Seq;
    is-deeply .child-asked-on-year.map(*.child).map(*.name).Seq, <Fernanda Sophia>.Seq;
}

is-deeply ChildAskedOnYear.^all.map(*.gift.name).Bag, bag <pokemon doll ball ball>;
is-deeply ChildAskedOnYear.^all.map(*.gift.name).Set, set <pokemon doll ball>;

isa-ok Child.^create(:name<Maricota>, :country<Brazil>), Child;
is Child.^all.elems, 3;
is-deeply Child.^all.grep(*.name.starts-with: "M").map(*.name).head, "Maricota";
is-deeply Gift.^all.grep(*.name.contains: "ll").map(*.name).Seq, <doll ball>.Seq;

done-testing;
