unit role Red::AST;
has Red::AST $.next;

multi method add(Red::AST:D: Red::AST:D $next) { if $!next { $!next.add: $next } else { $!next = $next } }
multi method add(Red::AST:U: Red::AST:D $next) { $next }

#method gist { ... }

#method should-set($class       --> Hash()) { ... }
#method should-validate(%values --> Bool()) { ... }

#method args { ... }

method transpose(&func) {
    for self.args -> $arg {
        $arg.?transpose: &func
    }
    func self;
}

method tables {
    my @tables;
    self.transpose: -> $ast {
        if $ast.^name eq "Red::Column" {
            @tables.push: $ast.class
        }
    }
    |@tables
}
