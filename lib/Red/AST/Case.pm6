use Red::AST;
use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
unit class Red::AST::Case does Red::AST;

has Red::AST $.case;
has Red::AST %.when{Red::AST};
has Red::AST $.else;

multi method new(Red::AST :$case, Red::AST :%when, Red::AST :$else is copy) {
    .return with self.optimize: :$case, :%when, :$else;

    ::?CLASS.bless: :$case, :%when, :$else
}

method args {
    $!case, |%!when.kv, $!else
}

method returns {
    #%!when.head.value.returns
}

method find-column-name {}
