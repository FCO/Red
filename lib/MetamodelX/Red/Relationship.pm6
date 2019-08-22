use Red::Attr::Relationship;
use Red::FromRelationship;
use Red::AST;

unit role MetamodelX::Red::Relationship;
has %!relationships{Attribute};

method relationships(|) {
    %!relationships
}

submethod !BUILD_pr(*%data) {
    my \instance = self;
    for self.^relationships.keys -> $rel {
        $rel.build-relationship: instance
    }
    for self.^attributes -> $attr {
        my $name = $attr.name.substr: 2;
        with %data{ $name } {
            $attr.set_value: instance, $_
        }
    }
    nextsame
}

method !get-build {
    & //= self.^find_private_method('BUILD_pr')
}

method prepare-relationships(::Type Mu \type) {
    my %rels  := %!relationships;
    my &build := self!get-build;

    if type.^declares_method("BUILD") {
        type.^find_method("BUILD", :no_fallback(1)).wrap: &build;
    } else {
        type.^add_method: "BUILD", &build
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
        ?? my method (Mu:U \SELF:) {
            my $ast = $attr.relationship-ast: SELF;
            $attr.package.^rs.new: :filter($ast)
        }
        !! my method (Mu:U \SELF:) {
            (
                $attr.has-lazy-relationship
                    ?? $attr.relationship-model
                    !! $attr.type
            ).^alias: "{ SELF.^as }_{ $name }", :base(SELF), :relationship($attr)
        }
    ;
}
