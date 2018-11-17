use Red::AST;
unit class Red::AST::Case does Red::AST;

has Red::AST $.case;
has Red::AST %.when{Red::AST};
has Red::AST $.else;

method args {
    $!case, |%!when.kv, $!else
}

method returns {
    %!when.head.value.returns
}
