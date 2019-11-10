use Red::AST::Value;
use Red::AST::Infix;
use Red::Type::Json;
unit class Red::AST::JsonRemoveItem does Red::AST::Infix;

has Str $.op = "->";

method returns { Json }

multi method new(::?CLASS $left, $right) {
    $left.clone: :right(ast-value [|$left.right, ast-value $right])
}