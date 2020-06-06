use Red::AST;
use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;

#| Represents a case statement
unit class Red::AST::Case does Red::AST;
#also does Red::AST::Optimizer::Case;

has Red::AST $.case;
has Red::AST %.when{Red::AST};
has Red::AST $.else;

multi method new(Red::AST :$case, Red::AST :%when, Red::AST :$else is copy) {
    my \case-ret = self.optimize: :$case, :%when, :$else;
    return case-ret if case-ret.DEFINITE && case-ret !~~ Empty;

    self.WHAT.bless: :$case, :%when, :$else
}

method args {
    $!case, |%!when.kv, $!else
}

method returns {
    #%!when.head.value.returns
}

method find-column-name {}
