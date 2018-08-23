use Red::AST::Infixes;
unit role Red::Attr::Relationship[&rel1, &rel2?];
has Mu:U $!type;

method build-relationship(\instance) {
    my \type = self.type;
    self.set_value: instance, Proxy.new:
        FETCH => method () {
            do if type ~~ Positional {
                my $rel = rel1 type.of;
                my \value = $rel.references.().attr.get_value: instance;
                type.of.^rs.where: Red::AST::Eq.new: $rel, value, :bind-right
            } else {
                my $rel = rel1 instance.WHAT;
                my \ref = $rel.references.();
                my \value = $rel.attr.get_value: instance;
                type.^rs.where(Red::AST::Eq.new: ref, value, :bind-right).head
            }
        },
        STORE => method ($value) {
            die "Couldnt set value"
        }
}

method relationship-ast {
    my \type = self.type ~~ Positional ?? self.type.of !! self.type;
    my $col1 = rel1 type;
    my $col2 = $col1.references.();
    Red::AST::Eq.new: $col1, $col2
}
