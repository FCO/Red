use Red::AST;
use Red::Column;
unit role Red::ResultSeq;

sub create-resultseq($rs-class-name, Mu \type) is export is raw {
    use Red::DefaultResultSeq;
    my $rs-class := Metamodel::ClassHOW.new_type: :name($rs-class-name);
    $rs-class.^add_parent: Red::DefaultResultSeq;
    $rs-class.^add_role: Red::ResultSeq;
    $rs-class.^add_method: "of", method { type }
    $rs-class.^compose;
    $rs-class
}

# method of {}
has Red::AST $.filter;

method do-it {
    use Red::DoneResultSeq;
    Red::DoneResultSeq.new: :of(self.of), :$!filter
}
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

#method iterator {
#    [self.of].iterator
#}

method grep(&filter)        { self.where: filter self.of }

multi treat-map($filter, Red::Model     $_, &filter, Bool :$flat                 ) { .^where: $filter }
multi treat-map($filter, Red::Column    $_, &filter, Bool :$flat                 ) { Red::DoneResultSeq.new: :of(.attr.type), :$filter }
multi treat-map($filter,                $_, &filter, Bool :$flat                 ) { .do-it.map: &filter } # FIXME: change to use count
multi treat-map($filter, Red::ResultSeq $_, &filter, Bool :$flat! where * == True) { $_ }

method map(&filter)         {
    treat-map $!filter, filter(self.of), &filter
}
method flatmap(&filter)     {
    treat-map :flat, $!filter, filter(self.of), &filter
}

method head { self.of.new } # FIXME
