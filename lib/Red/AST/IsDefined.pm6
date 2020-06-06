use Red::AST;
use Red::AST::Unary;
#| Represents "is defined" operation
#| usualy defined as:
#| type IS NULL
unit class Red::AST::IsDefined does Red::AST;

has $.col is required;

method new(::?CLASS:U: $col) {
    self.bless: :$col
}

method returns { Bool }

method args { $!col }

method not {
    Red::AST::Not.new: self
}

method find-column-name {
    $!col.name
}

method find-value {
    $!col
}

method gist { "{$!col.gist}.defined" }
