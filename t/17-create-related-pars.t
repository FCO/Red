use Test;
use Red;

model State is rw is table('foo') {
    has Int $.id            is serial;
    has Str $.name          is column{ :unique };
}

model Transition is rw {
    has Int $.id            is serial;
    has Str $.name          is column;
    has Int $.from-id       is referencing(model => 'State', column => 'id');
    has     $.from          is relationship(*.from-id, model => 'State');
    has Int $.to-id         is referencing(model => 'State', column => 'id');
    has     $.to            is relationship(*.to-id, model => 'State', :no-prefetch);
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(State, Transition).create;

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

my $t3 = Transition.^create: :name<other-name>, :from{ :name<three> }, :to{ :name<four> };

my $three = State.^load: :name<three>;
isa-ok $three, State;
my $four  = State.^load: :name<four>;
isa-ok $four, State;

is-deeply $t3.from, $three;
is-deeply $t3.to  , $four;

is-deeply $t3.from-id, $three.id;
is-deeply $t3.to-id  , $four.id;

done-testing
