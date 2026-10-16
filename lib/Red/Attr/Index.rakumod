unit role Red::Attr::Index;

has Callable $!index-expression;
has Bool $!unique-index;

method index-expression { $!index-expression }
method unique-index { $!unique-index }

method configure-index(Callable $expression, Bool :$unique = False) {
    $!index-expression = $expression;
    $!unique-index = $unique;
}
