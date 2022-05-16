use Red;

model Bla {
  has $.id    is serial;
  has $.value is column;
}

sub term:<bla-schema> is export {
  schema(Bla)
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
red-defaults $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

