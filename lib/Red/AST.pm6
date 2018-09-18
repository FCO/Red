unit role Red::AST;
has Red::AST $.next;

multi method add(Red::AST:D: Red::AST:D $next) { if $!next { $!next.add: $next } else { $!next = $next } }
multi method add(Red::AST:U: Red::AST:D $next) { $next }

#method gist { ... }

#method should-set($class       --> Hash()) { ... }
#method should-validate(%values --> Bool()) { ... }

#method args { ... }

method transpose(&func) {
    func self;
    for self.args -> $arg {
        $arg.transpose: &func
    }
}

method tables {
    my @tables;
    self.transpose: -> $ast {
    }
}
