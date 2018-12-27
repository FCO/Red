use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::Attr::Relationship[&rel1, &rel2?, Str :$model, Str :$require = $model];
has Mu:U $!type;

has Mu:U $!relationship-model;

has Bool $!loaded-model = False;

method relationship-model(--> Mu:U) {
    if !$!loaded-model {
        my $t = ::($model);
        if !$t && $t ~~ Failure {
            require ::($require);
            $t = ::($model);
        }
        $!relationship-model = $t;
        $!loaded-model = True;
    }
    $!relationship-model;
}

method set-data(\instance, Mu $value) {
    my $attr = rel1(self.package).attr;
    my $ref = rel1(self.package).ref;
    $attr.set_value: instance, $ref.attr.get_value: $value;
    instance.^set-dirty: $attr;
}

method build-relationship(\instance) {
    my \type = self.type;
    my \attr = self;
    my \rel-model = $model ?? self.relationship-model !! type ~~ Positional ?? type.of !! type;
    use nqp;
    nqp::bindattr(nqp::decont(instance), $.package, $.name, Proxy.new:
        FETCH => method () {
            do if type ~~ Positional {
                my $rel = rel1 rel-model;
                my $val = $rel.ref.attr.get_value: instance;
                my \value = ast-value $val;
                rel-model.^rs.where: Red::AST::Eq.new: $rel, value, :bind-right
            } else {
                my $rel = rel1 instance.WHAT;
                my $val = $rel.attr.get_value: instance;
                do with $val {
                    my \value = ast-value $val;
                    rel-model.^rs.where(Red::AST::Eq.new: $rel.ref, value, :bind-right).head
                } else {
                    rel-model
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
    my \type = self.type ~~ Positional ?? $model ?? self.relationship-model !! self.type.of !! self.type;
    my $col1 = rel1 type;
    my $col2 = $col1.ref;
    Red::AST::Eq.new: $col1, $col2
}
