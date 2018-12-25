use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::Attr::Relationship[&rel1, &rel2?];
has Mu:U $!type;

method set-data(\instance, Mu $value) {
    my $attr = rel1(self.package).attr;
    my $ref = rel1(self.package).ref;
    $attr.set_value: instance, $ref.attr.get_value: $value;
    instance.^set-dirty: $attr;
}

method build-relationship(\instance) {
    my \type = self.type;
    my \attr = self;
    use nqp;
    nqp::bindattr(nqp::decont(instance), $.package, $.name, Proxy.new:
        FETCH => method () {
            do if type ~~ Positional {
                my $rel = rel1 type.of;
                my $val = $rel.ref.attr.get_value: instance;
                my \value = ast-value $val;
                $rel.class.^rs.where: Red::AST::Eq.new: $rel, value, :bind-right
            } else {
                my $rel = rel1 instance.WHAT;
                my $val = $rel.attr.get_value: instance;
                do with $val {
                    my \value = ast-value $val;
                    $rel.ref.class.^rs.where(Red::AST::Eq.new: $rel.ref, value, :bind-right).head
                } else {
                    $rel.ref.class
                }
            }
        },
        STORE => method ($value where type) {
            die X::Assignment::RO.new(value => attr.type) unless attr.rw;
            if type !~~ Positional {
                attr.set-data: instance, $value
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
    my $col2 = $col1.ref;
    Red::AST::Eq.new: $col1, $col2
}
