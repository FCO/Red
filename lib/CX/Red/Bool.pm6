=head2 CX::Red::Bool

unit class CX::Red::Bool is X::Control;

#| Control Exception to help to understand what's happening
#| inside of blocks. Throwed on Red::AST.Bool

has      $.ast;
has Bool $.value;

method message { "<red bool control exception>" }
