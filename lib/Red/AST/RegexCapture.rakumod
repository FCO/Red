use Red::AST;
use Red::AST::RegexMatch;
use Red::AST::Unary;

#| A scalar text read from a regex guarded by the current compiled condition.
unit class Red::AST::RegexCapture does Red::AST;

has Red::AST::RegexMatch $.match is required;
has $.selection is required;
method returns { Str }
method args { $!match, $!selection }
method not { Red::AST::Not.new(self) }
method find-column-name { $!match.find-column-name }
