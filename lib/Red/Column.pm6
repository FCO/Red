use Red::Utils;
use Red::Model;
use Red::Filter;
unit class Red::Column;

has Attribute   $.attr is required;
has Bool        $.id               = False;
has Bool        $.relationship     = self.attr.type ~~ Red::Model;
has Bool        $.nullable         = quietly (self.attr.type.^name ~~ /<!after ":"> ":" ["_" | "U" | "D"]/).Str !eq ":D";
has Str         $.name             = kebab-to-snake-case self.attr.name.substr: 2;
has Mu          $.class is required;

method cast(Str $type) {
    Red::Filter.new: :op(cast), :args($type<>, self<>)
}
