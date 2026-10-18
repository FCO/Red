unit role Red::Attr::Index;

has Callable $!index-expression;
has Bool $!unique-index;
has Str $!index-kind = 'index';
has %!index-options;

method index-expression { $!index-expression }
method unique-index { $!unique-index }
method index-kind { $!index-kind }
method schema-options { %!index-options }

method configure-index(Callable $expression, Bool :$unique = False,
    Str :$kind = 'index', Str :$using = '', Str :$driver = '',
    :$opclass, Callable :$where = Callable) {
    $!index-expression = $expression;
    $!unique-index = $unique;
    $!index-kind = $kind;
    %!index-options = :$using, :$driver, :$opclass, :$where;
}
