use Red::AST::Value;
use Red::AST::Infix;
use Red::Type::Json;

#| Represents a json item
unit class Red::AST::JsonItem does Red::AST::Infix;

has Str $.op = "->";

method returns { Json }

multi method new(::?CLASS $left, $right) {
    my @path = $left.right ~~ Red::AST::Value && $left.right.value ~~ Positional
        ?? $left.right.value.list !! ($left.right,);
    $left.clone: :right(ast-value [|@path, ast-value($right)])
}
