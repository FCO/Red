unit role Red::AST;
has Red::AST @.next;

multi method add(Red::AST:D: Red::AST:D $next) { @!next.push: $next }
multi method add(Red::AST:U: Red::AST:D $next) { $next }

#method args { ... }
#method bind { ... }
#
#method gist { ... }

#method should-set($class       --> Hash()) { ... }
#method should-validate(%values --> Bool()) { ... }

method tables {
    gather for self.all-args {
        .class.take if .^can: "class";
        if .^can: "tables" {
            .take for |.tables
        }
    }
}

method all-args {
    my @binds = self.bind;
    gather for self.args {
        when Whatever {
            take @binds.shift
        }
        default {
            .take
        }
    }
}

method transpose(&agg, $data? is copy) {
    my @binds = self.bind;
    for self.all-args {
        when .^can("transpose") {
            $data = .transpose: $data, &agg
        }
        default {
            $data = agg $data, $_
        }
    }
    $data
}
