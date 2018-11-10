use Red::Utils;
use Red::Model;
use Red::AST;
use Red::AST::Unary;
unit class Red::Column does Red::AST;

has Attribute   $.attr is required;
has Str         $.attr-name        = $!attr.name.substr: 2;
has Bool        $.id               = False;
has Bool        $.auto-increment   = False;
has             &.references;
has             $!ref;
has Bool        $.nullable         = quietly (self.attr.type.^name ~~ /<!after ":"> ":" ["_" | "U" | "D"]/).Str !eq ":D";
has Str         $.name             = kebab-to-snake-case self.attr.name.substr: 2;
has Mu          $.class is required;
has Str         $.name-alias       = $!name;
has Str         $.type;
has             &.inflate          = *.self;
has             &.deflate          = *.self;
has             $.computation;

method ref {
    $!ref //= .() with &!references
}

method returns { $!class }

method transpose(&func) { func self }

method gist { "{$!class.^as}.{$!name-alias}" }

method cast(Str $type) {
    Red::AST::Cast.new: self, $type
}

method find-column-name {
    $!attr-name
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

method args {}
