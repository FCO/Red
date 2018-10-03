use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::Attr::Relationship[&rel1, &rel2?];
has Mu:U $!type;

method build-relationship(\instance) {
    my \type = self.type;
    my \attr = self;
    use nqp;
    nqp::bindattr(nqp::decont(instance), $.package, $.name, Proxy.new:
        FETCH => method () {
            $ //= do if type ~~ Positional {
                my $rel = rel1 type.of;
                my \value = ast-value $rel.references.().attr.get_value: instance;
                type.of.^rs.where: Red::AST::Eq.new: $rel, value, :bind-right
            } else {
                my $rel = rel1 instance.WHAT;
                my \ref = $rel.references.();
                my \value = ast-value $rel.attr.get_value: instance;
                type.^rs.where(Red::AST::Eq.new: ref, value, :bind-right).head
            }
        },
        STORE => method ($value where type) {
            die X::Assignment::RO.new(value => attr.type) unless attr.rw;
            if type !~~ Positional {
                rel1(attr.package).attr.set_value: instance, rel1(attr.package).references.().attr.get_value: $value;

            } else {
                die "NYI Couldnt set value"
            }
        }
    );
    return
}

method relationship-ast {
    my \type = self.type ~~ Positional ?? self.type.of !! self.type;
    my $col1 = rel1 type;
    my $col2 = $col1.references.();
    Red::AST::Eq.new: $col1, $col2
}
