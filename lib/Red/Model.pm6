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
