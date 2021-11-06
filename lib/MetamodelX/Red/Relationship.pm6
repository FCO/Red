use Red::Attr::Relationship;
use Red::FromRelationship;
use Red::AST;
use Red::Model;
=head2 MetamodelX::Red::Relationship

unit role MetamodelX::Red::Relationship;
has %!relationships{Attribute};

method relationships(|) {
    %!relationships
}

method has-one-relationships(|) {
    %!relationships.keys.grep: {
        .type !~~ Positional && !.no-prefetch
    }
}

method has-many-relationships(|) {
    %!relationships.keys.grep: {
        .type ~~ Positional
    }
}

method create-rel-name(Mu \instance, $name) { "{ instance.^as }_{ $name }" }

method !sel-scalar($attr, $name) {
    my method (Mu:U \SELF:) {
        SELF.^join(
            $attr.has-lazy-relationship
                    ?? $attr.relationship-model
                    !! $attr.type
            ,
            :name(SELF.^create-rel-name($name)),
            $attr,
            |$attr.join-type.Hash,
        )
    }
}

method !sel-positional($attr) {
    my method (Mu:U \SELF:) {
        my $ast = $attr.relationship-ast: SELF;
        ($attr.relationship-model ~~ Positional
            ?? $attr.relationship-model.of
            !! $attr.relationship-model
        ).^rs.new: :filter($ast)
    }
}

method !get-build {
    #& //= self.^find_private_method('BUILD_pr')
    method (*%data) {
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

#| Adds a new relationship by reference.
multi method add-relationship(
        Mu:U $self,
        Attribute $attr,
        &reference,
        Red::Model :$model-type!,
        Bool       :$optional,
        Bool       :$no-prefetch,
        Bool       :$has-one,
) {
    $attr does Red::Attr::Relationship[&reference, :$model-type, :$optional, :$no-prefetch, :$has-one];
    self.add-relationship: $self, $attr
}

#| Adds a new relationship by column.
multi method add-relationship(
        Mu:U $self,
        Attribute $attr,
        Str  :$column!,
        Str  :$model!,
        Str  :$require = $model,
        Bool :$optional,
        Bool :$no-prefetch,
        Bool :$has-one,
) {
    self.add-relationship: $self, $attr, { ."$column"() }, :$model, :$require, :$optional, :$no-prefetch, :$has-one
}

#| Adds a new relationship by reference.
multi method add-relationship(
        Mu:U $self,
        Attribute $attr,
        &reference,
        Str  :$model,
        Str  :$require = $model,
        Bool :$optional,
        Bool :$no-prefetch,
	    Bool :$has-one,
) {
    $attr does Red::Attr::Relationship[&reference, :$model, :$require, :$optional, :$no-prefetch, :$has-one];
    self.add-relationship: $self, $attr
}

#| Adds a new relationship by two references.
multi method add-relationship(
        Mu:U $self,
        Attribute $attr,
        &ref1,
        &ref2,
        Str  :$model,
        Str  :$require = $model,
        Bool :$optional,
        Bool :$no-prefetch,
	    Bool :$has-one,
) {
    $attr does Red::Attr::Relationship[&ref1, &ref2, :$model, :$require, :$optional, :$no-prefetch, :$has-one];
    self.add-relationship: $self, $attr
}

#| Adds a new relationship using an attribute of type `Red::Attr::Relationship`.
multi method add-relationship(::Type Mu:U $self, Red::Attr::Relationship $attr) {
    die ":has-one isn't accepted on relationship without its experimental feature (use Red <has-one>)"
    	if $attr.has-one and not %Red::experimentals<has-one>;
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
                my \value = nqp::getattr(self, self.WHAT, $attr.name);
                my $n = $self.WHAT."$name"();
                $n.^parent = self if $n.HOW.^can: "parent";
                return $n unless value;
                value
            }
        }
    }
    $attr.rel-name = self.create-rel-name($self, $name);
    $self.^add_multi_method: $name, $attr.type ~~ Positional || $attr.has-one
        ?? self!sel-positional($attr)
        !! self!sel-scalar($attr, $name);
    ;
}
