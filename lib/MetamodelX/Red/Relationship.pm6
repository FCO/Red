use Red::AttrRelationship;

unit role MetamodelX::Red::Relationship;
has %!relationships{Attribute};

method relationships(|) {
    %!relationships
}

method prepare-relationships(::Type Mu \type) {
    type.^add_method: 'new', my method new(Type: *%data) {
        my \instance = callsame;
        for self.^relationships.keys -> $rel {
            $rel.build-relationship: instance
        }
        instance
    }
}

multi method add-relationship(Mu:U $self, Attribute $attr, &reference) {
    $attr does Red::AttrRelationship[&reference];
    self.add-relationship: $self, $attr
}

multi method add-relationship(Mu:U $self, Attribute $attr, &ref1, &ref2) {
    $attr does Red::AttrRelationship[&ref1, &ref2];
    self.add-relationship: $self, $attr
}

multi method add-relationship(Mu:U $self, Red::AttrRelationship $attr) {
    %!relationships ∪= $attr
}
