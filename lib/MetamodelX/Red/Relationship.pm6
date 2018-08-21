use Red::FakeSeq;
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
    %!relationships ∪= $attr;
    my $name = $attr.name.substr(2);
    $self.^add_multi_method: $name, my method (Mu:D:) {
        $attr.get_value: self
    } if $attr.has_accessor;
    $self.^add_multi_method: $name, my method (Mu:U:) {
        # TODO: use fake seq
    #    Red::FakeSeq.new: :of($self.WHAT), :ast($attr.relationship-ast)
        my $ast = $attr.relationship-ast;
        Red::FakeSeq.new: :of($self.WHAT), :$ast
    }
}
