use Red::AST::Infix;
use Red::Type::Json;

#| Represents an update to a JSON path.
unit class Red::AST::JsonSetItem does Red::AST::Infix;

has Red::AST $.value is required;

proto method new(|) {*}

multi method new(Red::AST :$left!, Red::AST :$right!, Red::AST :$value!) {
    self.bless: :$left, :$right, :$value
}

method returns { Json }
method args { $.left, $.right, $.value }
method op { "json-set" }
