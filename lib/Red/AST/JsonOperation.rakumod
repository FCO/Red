use Red::AST;
use Red::AST::Unary;

#| Represents JSON existence, size, or containment.
unit class Red::AST::JsonOperation does Red::AST;

has Str $.operation is required where <exists elems contains>.any;
has Red::AST $.value is required;
has Red::AST $.argument;

method returns { $.operation eq "elems" ?? Int !! Bool }
method args { $.value, |($.argument if $.argument.defined) }
method find-column-name { $.value.find-column-name }
method not { Red::AST::Not.new(self) }
