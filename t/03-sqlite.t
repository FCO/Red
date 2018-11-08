use Test;
use Red;

plan 2;

my $*RED-DB = database "Mock";
$*RED-DB.die-on-unexpected;

model ExampleModel { has Int $.col is column }

$*RED-DB.when: "CREATE TABLE example_model(col INTEGER NULL)", :once, :return[];

ExampleModel.^create-table;

$*RED-DB.when: rx:i/SELECT \s+ "example_model.col"/, :once, :return[{:10data}, {:20data}, {:30data}];

is (10, 20, 30), ExampleModel.^all.map({ .col }), "map is working";

$*RED-DB.verify;
