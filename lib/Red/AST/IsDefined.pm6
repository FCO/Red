use Red::AST;
unit class Red::AST::IsDefined does Red::AST;

has $.col is required;

method new(::?CLASS:U: $col) {
    self.bless: :$col
}

method returns { Bool }

method args { $!col }
