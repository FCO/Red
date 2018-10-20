use Test;
use Red;

plan 2;

my $*RED-DEBUG = True;
my $*RED-DB = database "Mock";
$*RED-DB.die-on-unexpected;

model ExampleModel { has Int $.col is column }

$*RED-DB.when: "create table example_model(col integer null)", :once, :return[];

ExampleModel.^create-table;

$*RED-DB.when: rx/select \s+ col/, :once, :return[{:10data}, {:20data}, {:30data}];

is (10, 20, 30), ExampleModel.^all.map({ .col }), "map is working";

$*RED-DB.verify;
