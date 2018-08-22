use Red::AST;
unit role Red::Model;

has $!filter;
multi method grep(Red::AST:D $filter) {
    self.^rs.grep: $filter
}

multi method grep(&filter) {
    self.^rs.grep: filter ::?CLASS
}

method gist { self.perl }

multi method grep(   Mu:U: &func) { self.^rs.grep:    &func }
multi method map(    Mu:U: &func) { self.^rs.map:     &func }
multi method flatmap(Mu:U: &func) { self.^rs.flatmap: &func }
