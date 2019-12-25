use Test;
use Red;
use Red::AST::Generic::Infix;
use Red::AST::Generic::Prefix;
use Red::AST::Generic::Postfix;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

model Bla { has $!id is serial; has Int $.val is column }

Bla.^create-table;
Bla.^create: :1val;

is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("=="), 42, 42 }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("<>"), 42, 42 }).map(*.val), ();

is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("=="), 42, 42, :bind-left }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("<>"), 42, 42, :bind-left }).map(*.val), ();

is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("=="), 42, 42, :bind-right }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("<>"), 42, 42, :bind-right }).map(*.val), ();

is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("=="), 42, 42, :bind-left, :bind-right }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Infix.new: :op("<>"), 42, 42, :bind-left, :bind-right }).map(*.val), ();


is Bla.^all.grep({ Red::AST::Generic::Prefix.new: :op("not"), False }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Prefix.new: :op("not"), True }).map(*.val), ();

is Bla.^all.grep({ Red::AST::Generic::Prefix.new: :op("not"), False, :bind }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Prefix.new: :op("not"), True,  :bind }).map(*.val), ();


is Bla.^all.grep({ Red::AST::Generic::Postfix.new: :op("AND 1"), True  }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Postfix.new: :op("AND 1"), False }).map(*.val), ();

is Bla.^all.grep({ Red::AST::Generic::Postfix.new: :op("AND 1"), True, :bind }).map(*.val), (1);
is Bla.^all.grep({ Red::AST::Generic::Postfix.new: :op("AND 1"), False,  :bind }).map(*.val), ();

done-testing;
