use Red::AST;
unit role Red::ResultSeq;

has Red::AST $.filter;

#multi method grep(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method where(::?CLASS:U: Red::AST:U $filter) { self.WHAT  }
multi method where(::?CLASS:D: Red::AST:U $filter) { self.clone }
multi method where(::?CLASS:U: Red::AST:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::AST:D $filter) {
    self.WHAT.new: :filter($!filter.add: $filter)
}

method transform-item(*%data) {
    self.of.bless: |%data
}

method iterator {
    [self.of].iterator
}

method grep(&filter) { self.where: filter self.of }
