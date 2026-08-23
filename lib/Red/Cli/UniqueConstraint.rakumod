use Red::Utils;
use Red::DB;
use Red::Cli::Column;
unit class Red::Cli::UniqueConstraint;

has     $.table      is rw;
has Str $.name       is required;
has Str @.columns;

multi method new($name, @columns) {
    self.bless: :$name, :@columns
}

multi method gist(::?CLASS:D:) {
    "Red::Cli::UniqueConstraint.new(:name($!name), :columns<{ @!columns.join: " " }> #`( table => $!table.name() ))"
}

method Str { $.gist }

multi method WHICH(::?CLASS:D:) {
    ValueObjAt.new: $.gist
}

method to-code(Str :$schema-class) {
    die "NYI";
}
