use Red::Attr::Relationship;

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

multi method add-relationship(Mu:U $self, Attribute $attr, &reference) {
    $attr does Red::Attr::Relationship[&reference];
    self.add-relationship: $self, $attr
}

multi method add-relationship(Mu:U $self, Attribute $attr, &ref1, &ref2) {
    $attr does Red::Attr::Relationship[&ref1, &ref2];
    self.add-relationship: $self, $attr
}

multi method add-relationship(Mu:U $self, Red::Attr::Relationship $attr) {
    %!relationships ∪= $attr;
    my $name = $attr.name.substr(2);
    $self.^add_multi_method: $name, my method (Mu:D:) {
        $attr.get_value(self).self
    } if $attr.has_accessor;
    $self.^add_multi_method: $name, my method (Mu:U:) {
        my $ast = $attr.relationship-ast;
        $attr.package.^rs.new: :filter($ast)
    }
}
