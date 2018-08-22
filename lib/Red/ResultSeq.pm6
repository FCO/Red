use Red::AST;
use Red::Model;
use Red::Query;
unit role Red::ResultSeq;

has Red::AST $.filter;

multi method grep(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method grep(::?CLASS:U: Red::AST:D $filter) { self.new: :$filter }
multi method grep(::?CLASS:D: Red::AST:D $filter) { self.clone: :filter($!filter.merge: $filter) }

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

method query(Red::AST $filter?) {
    Red::Query.new: :base-table(self.of), :$!filter
}
