use Red::AST;
unit role Red::Model;

has $!filter;
multi method grep(Red::AST $filter) {
    self.^rs.grep: $filter
}

multi method grep(&filter) {
    self.^rs.grep: filter ::?CLASS
}

method all { self.^rs }

method gist { self.perl }
