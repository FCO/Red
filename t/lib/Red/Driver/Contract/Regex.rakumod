use Red::Regex;
unit class Red::Driver::Contract::Regex is Red::Regex;

method render-info(*%options --> Hash:D) {
    %(pattern => self.tree[1], groups => Map.new)
}
