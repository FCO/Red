use Red::AST;
use Red::Operators;
unit role Red::AttrRelationship[&rel1, &rel2?];

method build-relationship(\instance) {
    my \type = self.type;
    self.set_value: instance, Proxy.new:
        FETCH => method () {
            do if type ~~ Positional {
                my $rel = rel1 type.of;
                my \value = $rel.references.().attr.get_value: instance;
                type.of.where: Red::AST.new: :op(Red::Op::eq), :args($rel,), :bind(value, )
            } else {
                my $rel = rel1 instance.WHAT;
                my \ref = $rel.references.();
                my \value = $rel.attr.get_value: instance;
                type.where(Red::AST.new: :op(Red::Op::eq), :args(ref,), :bind(value, )).head
            }
        },
        STORE => method ($value) {
            die "Couldnt set value"
        }
}
