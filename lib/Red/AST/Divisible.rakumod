use Red::AST::Infix;

#| Represents a "is divisable" operation
#| usually implemented as (num1 % num2 == 0)
unit class Red::AST::Divisible does Red::AST::Infix;
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
