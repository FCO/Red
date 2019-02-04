use Test;
use Red;

model Foo {
    has Int $.bar is serial;
    has Str $.foo is column;
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);

Foo.^create-table;

is ?Foo.^all, False;

Foo.^create: foo => "babaa";

is ?Foo.^all, True;

done-testing
