#| Control Exception to help to understand what's happening
#| inside of blocks. Throwed on Red::AST.Bool
unit class CX::Red::Bool is X::Control;

has      $.ast;
has Bool $.value;

method message { "<red bool control exception>" }
