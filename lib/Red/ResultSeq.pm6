use Red::AST;
use Red::Column;
use Red::AST::Value;
use Red::AST::Delete;
use Red::Attr::Column;
use Red::AST::Infixes;
use Red::AST::Chained;
use Red::AST::Function;
use Red::ResultAssociative;
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

has Red::AST::Chained $.chain handles <filter limit post order group table-list> .= new;

method iterator {
    Red::ResultSeq::Iterator.new: :of($.of), :$.filter, :$.limit, :&.post, :@.order, :@.table-list, :@.group
}

method Seq {
    Seq.new: self.iterator
}

method do-it(*%pars) {
    self.clone(|%pars).Seq
}

#multi method grep(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method where(::?CLASS:U: Red::AST:U $filter) { self.WHAT  }
multi method where(::?CLASS:D: Red::AST:U $filter) { self.clone }
multi method where(::?CLASS:U: Red::AST:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::AST:D $filter) {
    self.clone: :filter(($.filter, $filter).grep({ .defined }).reduce: { Red::AST::AND.new: $^a, $^b })
}

method transform-item(*%data) {
    self.of.bless: |%data
}

method grep(&filter)        { self.where: filter self.of }
method first(&filter)       { self.grep(&filter).head }

#multi treat-map($seq, $filter, Red::Model     $_, &filter, Bool :$flat                 ) { .^where: $filter }
#multi treat-map($seq, $filter,                $_, &filter, Bool :$flat                 ) { $seq.do-it.map: &filter }
#multi treat-map($seq, $filter, Red::ResultSeq $_, &filter, Bool :$flat! where * == True) { $_ }
#multi treat-map($seq, $filter, Red::Column    $_, &filter, Bool :$flat                 ) {
#}

multi method create-map($_, &filter)        { self.do-it.map: &filter }
multi method create-map(Red::Model  $_, &?) { .^where: $.filter }
multi method create-map(Red::AST    $_, &?) {
    require ::("MetamodelX::Red::Model");
    my \Meta  = ::("MetamodelX::Red::Model").WHAT;
    my \model = Meta.new.new_type;
    my $attr  = Attribute.new: :name<$!data>, :package(model), :type(.returns), :has_accessor, :build(.returns);
    my $col   = Red::Column.new: :name-alias<data>, :attr-name<data>, :type(.returns.^name), :$attr, :class(model), :computation($_);
    $attr does Red::Attr::Column($col);
    model.^add_attribute: $attr;
    model.^add_method: "no-table", my method no-table { True }
    model.^compose;
    model.^add-column: $attr;
    self.clone(
        :chain($!chain.clone:
            :post({ .data }),
            :$.filter,
            :table-list[(|@.table-list, self.of).unique],
            |%_
        )
    ) but role :: { method of { model } }
}
multi method create-map(Red::Column $_, &?) {
    my \Meta  = .class.HOW.WHAT;
    my \model = Meta.new.new_type;
    my $attr  = Attribute.new: :name<$!data>, :package(model), :type(.attr.type), :has_accessor, :build(.attr.type);
    my $col   = .attr.column.clone: :name-alias<data>, :attr-name<data>;
    $attr does Red::Attr::Column($col);
    model.^add_attribute: $attr;
    model.^add_method: "no-table", my method no-table { True }
    model.^compose;
    model.^add-column: $attr;
    self.clone(
        :chain($!chain.clone:
            :post({ .data }),
            :$.filter,
            :table-list[(|@.table-list, self.of).unique],
            |%_
        )
    ) but role :: { method of { model } }
}

method map(&filter) {
    self.create-map: filter(self.of), &filter
}
#method flatmap(&filter) {
#    treat-map :flat, $.filter, filter(self.of), &filter
#}

method sort(&order) {
    my @order = order self.of;
    self.clone: :@order
}

method classify(&func, :&as = { $_ }) {
    my $key   = func self.of;
    my $value = as   self.of;
    #self.clone(:group(func self.of)) but role :: { method of { Associative[$value.WHAT, Str] } }
    Red::ResultAssociative[$value, $key].new: :$.filter, :rs(self)
}

multi method head {
    self.do-it(:1limit).head
}

multi method head(UInt:D $num) {
    self.do-it(:limit(min $num, $.limit)).head: $num
}

method elems {
    self.create-map: Red::AST::Function.new: :func<count>, :args[ast-value *]
}

method new-object(::?CLASS:D: *%pars) {
    my %data = $.filter.should-set;
    my \obj = self.of.bless;#: |%pars, |%data;
    for %(|%pars, |%data).kv -> $key, $val {
        obj.^set-attr: $key, $val
    }
    obj
}

method create(::?CLASS:D: *%pars) {
    $.of.^create: |%pars, |(.should-set with $.filter);
}

method delete(::?CLASS:D:) {
    $*RED-DB.execute: Red::AST::Delete.new: $.of, $.filter
}
