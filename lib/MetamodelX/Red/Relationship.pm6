use Red::Attr::Relationship;
use Red::AST;

unit role MetamodelX::Red::Relationship;
has %!relationships{Attribute};

method relationships(|) {
    %!relationships
}

method prepare-relationships(::Type Mu \type) {
    my %rels := %!relationships;
    my &meth = my submethod BUILD(*%data) {
        my \instance = self;
        for %rels.keys -> $rel {
            $rel.build-relationship: instance
        }
        for self.^attributes -> $attr {
            with %data{ $attr.name.substr: 2 } {
                $attr.set_value: self, $_
            }
        }
        nextsame
    }

    if type.^declares_method("BUILD") {
        type.^find_method("BUILD", :no_fallback(1)).wrap: &meth;
    } else {
        type.^add_method: "BUILD", &meth
    }
}

multi method add-relationship(Mu:U $self, Attribute $attr, Str :$column!, Str :$model!, Str :$require = $model ) {
    self.add-relationship: $self, $attr, { ."$column"() }, :$model, :$require
}

multi method add-relationship(Mu:U $self, Attribute $attr, &reference, Str :$model, Str :$require = $model) {
    $attr does Red::Attr::Relationship[&reference, :$model, :$require];
    self.add-relationship: $self, $attr
}

multi method add-relationship(Mu:U $self, Attribute $attr, &ref1, &ref2, Str :$model, Str :$require  = $model) {
    $attr does Red::Attr::Relationship[&ref1, &ref2, :$model, :$require];
    self.add-relationship: $self, $attr
}

multi method add-relationship(::Type Mu:U $self, Red::Attr::Relationship $attr) {
    %!relationships ∪= $attr;
    my $name = $attr.name.substr: 2;
    if $attr.has_accessor {
        if $attr.type ~~ Positional {
            $self.^add_multi_method: $name, my method (Mu:D:) {
                $attr.get_value(self).self
            }
        } elsif($attr.rw) {
            $self.^add_multi_method: $name, my method (Mu:D:) is rw {
                my \SELF = self;
                Proxy.new:
                    FETCH => method { $attr.get_value(SELF) },
                    STORE => method (\value) {
                        $attr.set-data: SELF, value
                    }
                ;
            }
        } else {
            $self.^add_multi_method: $name, my method (Mu:D:) is rw {
                use nqp;
                nqp::getattr(self, self.WHAT, $attr.name)
            }
        }
    }
    $self.^add_multi_method: $name, $attr.type ~~ Positional
        ?? my method (Mu:U:) {
            my $ast = $attr.relationship-ast;
            $attr.package.^rs.new: :filter($ast)
        }
        !! my method (Mu:U:) {
            if ($*RED-GREP-FILTER && $*RED-GREP-FILTER ~~ Red::AST).Bool {
                $*RED-GREP-FILTER = $attr.relationship-ast
            }
            $attr.has-lazy-relationship ?? $attr.relationship-model !! $attr.type;
        }
    ;
}
