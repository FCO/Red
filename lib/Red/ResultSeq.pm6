use Red::Filter;
use Red::Model;
unit role Red::ResultSeq;

has Red::Filter $.filter;

multi method where(::?CLASS:U: Red::Filter:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::Filter:D $filter) { self.clone: :filter($!filter.merge: $filter) }

method to-many(Red::Model:D $model, Str $rel-name) {
    my \col-rel = self.of.HOW.relations{$rel-name};

    self.where: Red::Filter.new: :op(Red::Op::eq), :args(col-rel, col-rel.references.().attr.get_value: $model)
}

method transform-item(*%data) {
    self.of.bless: |%data
}

method iterator {
    my $resultseq = self;
    class :: does Iterator {
        method pull-one {
            $resultseq.transform-item
        }
    }
}
