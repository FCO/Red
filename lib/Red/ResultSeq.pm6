use Red::Filter;
use Red::Model;
use Red::Query;
unit role Red::ResultSeq;

has Red::Filter $.filter;

multi method where(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method where(::?CLASS:U: Red::Filter:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::Filter:D $filter) { self.clone: :filter($!filter.merge: $filter) }

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

method query(Red::Filter $filter?) {
    Red::Query.new: :base-table(self.of), :$!filter
}
