use Red::AST;
use Red::Column;
use Red::Attr::Column;
use Red::AST::Infixes;
use Red::ResultSeq::Iterator;
unit role Red::ResultSeq[Mu $of = Any] does Sequence does Positional[$of];

sub create-resultseq($rs-class-name, Mu \type) is export is raw {
    use Red::DefaultResultSeq;
    my $rs-class := Metamodel::ClassHOW.new_type: :name($rs-class-name);
    $rs-class.^add_parent: Red::DefaultResultSeq;
    $rs-class.^add_role: Red::ResultSeq[type];
    $rs-class.^compose;
    $rs-class
}

method of { $of }
has Red::AST    $.filter;
has Int         $.limit;
has             &.post;
has Red::Column @.order;

method iterator {
    Red::ResultSeq::Iterator.new: :of($.of), :$!filter, :$!limit, :&!post, :@!order
}

method do-it(*%pars) {
    Seq.new: self.iterator
}

#multi method grep(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method where(::?CLASS:U: Red::AST:U $filter) { self.WHAT  }
multi method where(::?CLASS:D: Red::AST:U $filter) { self.clone }
multi method where(::?CLASS:U: Red::AST:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::AST:D $filter) {
    self.clone: :filter(($!filter, $filter).grep({ .defined }).reduce: { Red::AST::AND.new: $^a, $^b })
}

method transform-item(*%data) {
    self.of.bless: |%data
}

method grep(&filter)        { self.where: filter self.of }
method first(&filter)       { self.grep(&filter).head }

multi treat-map($seq, $filter, Red::Model     $_, &filter, Bool :$flat                 ) { .^where: $filter }
multi treat-map($seq, $filter,                $_, &filter, Bool :$flat                 ) { .do-it.map: &filter } # FIXME: change to use count
multi treat-map($seq, $filter, Red::ResultSeq $_, &filter, Bool :$flat! where * == True) { $_ }
multi treat-map($seq, $filter, Red::Column    $_, &filter, Bool :$flat                 ) {
    my \Meta = .class.HOW.WHAT;
    my \model = Meta.new.new_type;
    my $attr = Attribute.new: :name<$!data>, :package(model), :type(.attr.type), :has_accessor;
    my $col  = .attr.column.clone: :name-alias<data>, :attr-name<data>;
    $attr does Red::Attr::Column($col);
    model.^add_attribute: $attr;
    model.^add_method: "no-table", my method no-table { True }
    model.^compose;
    model.^add-column: $attr;
    $seq.clone(
        :post({ .data }),
        :$filter,
    ) but role :: { method of { model } }
}

method map(&filter)         {
    treat-map self, $!filter, filter(self.of), &filter
}
method flatmap(&filter)     {
    treat-map :flat, $!filter, filter(self.of), &filter
}

method sort(&order) {
    my @order = order self.of;
    self.clone: :@order
}

multi method head {
    self.do-it(:1limit).head
}

multi method head(UInt:D $num) {
    self.do-it(:limit(min $num, $!limit)).head: $num
}

method new-object(::?CLASS:D: *%pars) {
    my %data = $!filter.should-set;
    my \obj = self.of.bless;#: |%pars, |%data;
    for %(|%pars, |%data).kv -> $key, $val {
        obj.^set-attr: $key, $val
    }
    obj
}

method create(::?CLASS:D: *%pars) {
    my $new = self.new-object: |%pars;
    $new.^save: :insert;
    $new
}
