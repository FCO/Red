use Test;
use Red;

plan 2;

my $*RED-DB = database "Mock";
my $*RED-DEBUG = True if %*ENV<RED_DEBUG>;
$*RED-DB.die-on-unexpected;

model ExampleModel { has Int $.col is column }

$*RED-DB.when: "CREATE TABLE example_model(col INTEGER NOT NULL)", :once, :return[];

ExampleModel.^create-table;

$*RED-DB.when: rx:i/SELECT \s+ ["example_model."]? "col"/, :once, :return[{:10data_1}, {:20data_1}, {:30data_1}];

is (10, 20, 30), ExampleModel.^all.map({ .col }), "map is working";

model Example2Model is nullable { has Int $.col is column }

$*RED-DB.when: "CREATE TABLE example2_model(col INTEGER NULL)", :once, :return[];

Example2Model.^create-table;

$*RED-DB.verify;
