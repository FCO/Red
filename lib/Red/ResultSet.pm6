use Red::Filter;
use Red::Model;
unit role Red::ResultSet;

has Red::Filter $.filter;

multi method where(::?CLASS:U: Red::Filter:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::Filter:D $filter) { self.clone: :filter($!filter.merge: $filter) }

method relationship(Red::Model:D $model, Str $rel-name) {
    my \col-rel = self.of.HOW.relations{$rel-name};

    self.new: filter => Red::Filter.new: :op(Red::Op::eq), :args(col-rel, col-rel.references.().attr.get_value: $model)
}
