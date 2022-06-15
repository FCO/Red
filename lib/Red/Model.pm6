use Red::AST;

=head2 Red::Model

#| Base role for models
unit role Red::Model;

has $!filter;
#method gist { self.^attributes; #`{self.perl} }

multi method perl(::?CLASS:D:) {
    my @attrs = self.^attributes.grep({ !.^can("relationship-ast") && .has_accessor}).map: {
        "{ .name.substr(2) } => { .get_value(self).perl }"
    }
    "{ self.^name }.new({ @attrs.join: ", " })"
}

method new(*%pars) is hidden-from-backtrace {
    my @columns = self.^columns;
    for @columns -> \col {
        my $name = col.name.substr: 2;
        if %pars{$name}:exists {
            my \value = %pars{$name}<>;
            my $is-rtype = col.type.?is-red-type(col.type);
            die X::TypeCheck::Assignment.new(symbol => col.name, got => value, expected => col.type)
                unless ( !$is-rtype && value ~~ col.type ) || ( $is-rtype && col.type.red-type-accepts: value.WHAT );
        }
    }
    nextwith |%pars
}
