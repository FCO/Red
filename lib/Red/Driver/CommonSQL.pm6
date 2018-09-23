use Red::AST;
use Red::Column;
use Red::AST::Infix;
use Red::AST::Select;
use Red::AST::Unary;
use Red::AST::Value;
use Red::Driver;
unit role Red::Driver::CommonSQL does Red::Driver;

proto method translate(Red::AST) {*}

multi method translate(Red::AST::Select $_, $context?) {
    my $tables = .tables.map({ .^table }).join: ", ";
    my $where  = self.translate: .filter;
    "SELECT * FROM $tables WHERE $where", []
}

multi method translate(Red::AST::Infix $_, $context?) {
    "{ self.translate: .left } { .op } { self.translate: .right }"
}

multi method translate(Red::Column $_, $context?) {
    .name
}

multi method translate(Red::AST::Cast $_, $context?) {
    when Red::AST::Value {
        qq|'{ .value }'|
    }
    default {
        self.translate: .value
    }
}

multi method translate(Red::AST::Value $_, $context?) {
    qq|'{ .value }'|
}

