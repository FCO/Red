use Red;
use Test;

model User {
    has Int $.id   is serial;
    has Str $.name is column;
    has Str $.role is column;
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(User).drop.create;

my \Admin = User.^submodel: "Admin", *.role eq "admin";

ok User.new(:name<bla>, :role<admin>) ~~ Admin;
ok not (User.new(:name<bla>, :role<user>) ~~ Admin);

for <user admin root> -> Str $role {
    User.^create: :name("user " ~ ++$), :$role
}

is Admin.^all.map(*.name).Seq, "user 2";

lives-ok {
    Admin.^create: :name<anotherAdmin>
}


is Admin.^all.map(*.name).Seq, <<"user 2" anotherAdmin>>;

done-testing
