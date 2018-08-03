use Red::Utils;
use Red::ResultSet;
unit role Red::Column;

has Bool $.is-id            = False;
has Bool $.is-relationship  = self.type ~~ Red::ResultSet;
has Bool $.is-nullable      = quietly (self.type.^name ~~ /<!after ":"> ":" ["_" | "U" | "D"]/).Str !eq ":D";
has Str  $.column-name      = kebab-to-snake-case self.name.substr: 2;
