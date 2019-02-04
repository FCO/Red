use Test;
use Red;

model State is rw is table('foo') {
    has Int $.id            is serial;
    has Str $.name          is column;
}

model Transition is rw {
    has Int $.id            is serial;
    has Str $.name          is column;
    has Int $.from-id       is referencing(model => 'State', column => 'id');
    has     $.from          is relationship({  .from-id }, model => 'State');
    has Int $.to-id         is referencing(model => 'State', column => 'id');
    has     $.to            is relationship({  .to-id }, model => 'State');
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

State.^create-table;
Transition.^create-table;

my $one = State.^create: name => "one";
my $two = State.^create: name => "two";

my $trans1 = Transition.new: name => "name", from => $one, to => $two;

is-deeply $trans1.from, $one;
is-deeply $trans1.to  , $two;

is-deeply $trans1.from-id, $one.id;
is-deeply $trans1.to-id  , $two.id;

my $trans2 = Transition.^create: name => "name", from => $one, to => $two;

is-deeply $trans2.from, $one;
is-deeply $trans2.to  , $two;

is-deeply $trans2.from-id, $one.id;
is-deeply $trans2.to-id  , $two.id;

done-testing
