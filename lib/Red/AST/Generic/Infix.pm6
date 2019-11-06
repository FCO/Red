use Red::AST::Infix;
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

multi method new(Red::AST $left, Red::AST $right, Str :$op, :$returns) {
    self.bless: :$left, :$right, :$op, :$returns
}