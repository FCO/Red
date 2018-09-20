use Red::AST;
unit role Red::Model;

has $!filter;
method gist { self.perl }
