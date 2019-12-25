use Red::AST::Unary;
use Red::AST::Value;
unit class Red::AST::Generic::Prefix does Red::AST::Unary;

has Str $.op is required;
has $.returns;
has $.value;

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

method new($value, Str :$op, :$returns, Bool :$bind) {
    self.bless: :value(ast-value $value), :$op, :$returns, :$bind
}