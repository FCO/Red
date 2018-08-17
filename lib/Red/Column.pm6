use Red::Utils;
use Red::Model;
use Red::AST;
unit class Red::Column;

has Attribute   $.attr is required;
has Str         $.attr-name        = $!attr.name.substr: 2;
has Bool        $.id               = False;
has             &.references;
has Bool        $.nullable         = quietly (self.attr.type.^name ~~ /<!after ":"> ":" ["_" | "U" | "D"]/).Str !eq ":D";
has Str         $.name             = kebab-to-snake-case self.attr.name.substr: 2;
has Mu          $.class is required;
has Str         $.name-alias;

method cast(Str $type) {
    Red::AST.new: :op(cast), :args($type<>, self<>)
}

method alias(Str $name) {
    self.clone: name-alias => $name
}

method as(Str $name, :$nullable = True) {
    self.clone: attr-name => $name, :$name, id => False, :$nullable, attr => Attribute, class => Mu
}

method TWEAK(:$unique) {
    if $unique {
        $!attr.package.^add-unique-constraint: { self }
    }
}
