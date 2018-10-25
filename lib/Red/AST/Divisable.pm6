use Red::AST::Infix;
unit class Red::AST::Divisable does Red::AST::Infix;
has $.op = "%%";
has Bool $.returns;

method should-set(--> Hash()) {
    self.find-column-name => self.find-value
}

method should-validate {}

method find-column-name {
    for self.args {
        .return with .?find-column-name
    }
}

method find-value {
    for self.args {
        .return with .?find-value
    }
}
