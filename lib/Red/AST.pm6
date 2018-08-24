unit role Red::AST;
has Red::AST @.next;

multi method add(Red::AST:D: Red::AST:D $next) { @!next.push: $next }
multi method add(Red::AST:U: Red::AST:D $next) { $next }

#method gist { ... }

#method should-set($class       --> Hash()) { ... }
#method should-validate(%values --> Bool()) { ... }

method transpose(&func) {
    func self
}
