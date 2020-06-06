use Red::AST::Infix;
use Red::AST::Value;
unit class Red::AST::Generic::Infix does Red::AST::Infix;

has Str $.op is required;
has $.returns;

method should-set(--> Hash()) {
    self.find-column-name => self.find-value
}

method should-validate {}

method find-column-name {
    gather for self.args {
        .take for .?find-column-name
    }
}

method find-value {
    for self.args {
        .return with .?find-value
    }
}

multi method new($left, $right, Str :$op, :$returns, Bool :$bind-left, Bool :$bind-right) {
    self.bless:
            :left(ast-value $left),
            :right(ast-value $right),
            :$op,
            :$returns,
            :$bind-left,
            :$bind-right
}