use Red::AST;
use Red::Column;
use Red::AST::Next;
use Red::AST::Case;
use Red::AST::Empty;
use Red::AST::Value;
use Red::AST::Update;
use Red::AST::Delete;
use Red::Attr::Column;
use Red::AST::Infixes;
use Red::AST::Chained;
use Red::AST::Function;
use Red::AST::MultiSelect;
use Red::ResultAssociative;
use Red::ResultSeq::Iterator;
unit role Red::ResultSeq[Mu $of = Any] does Sequence;

sub create-resultseq($rs-class-name, Mu \type) is export is raw {
    use Red::DefaultResultSeq;
    my $rs-class := Metamodel::ClassHOW.new_type: :name($rs-class-name);
    $rs-class.^add_parent: Red::DefaultResultSeq;
    $rs-class.^add_role: Red::ResultSeq[type];
    $rs-class.^add_role: Iterable;
    $rs-class.^compose;
    $rs-class
}

method of { $of }
#method is-lazy { True }
method cache {
    List.from-iterator: self.iterator
}

has Red::AST::Chained $.chain handles <filter limit post order group table-list> .= new;
has Red::AST          %.update;

method iterator {
    Red::ResultSeq::Iterator.new: :$.of, :$.ast, :&.post
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
multi method where(::?CLASS:U: Red::AST:D $filter) { self.new: :chain($!chain.clone: :$filter) }
multi method where(::?CLASS:D: Red::AST:D $filter) {
    self.clone: :chain($!chain.clone: :filter(($.filter, $filter).grep({ .defined }).reduce: { Red::AST::AND.new: $^a, $^b }))
}

method transform-item(*%data) {
    self.of.bless: |%data
}

method grep(&filter)        {
    my Red::AST $*RED-GREP-FILTER;
    my $filter = filter self.of;
    with $*RED-GREP-FILTER {
        $filter = Red::AST::AND.new: $_, $filter
    }
    self.where: $filter;
}
method first(&filter)       { self.grep(&filter).head }

sub hash-to-cond(%val) {
    my Red::AST $ast;
    for %val.kv -> Red::AST $cond, Bool $so {
        my Red::AST $filter = $so ?? Red::AST::So.new($cond) !! $cond.not;
        with $ast {
            $ast = Red::AST::AND.new: $ast, $filter
        } else {
            $ast = $filter
        }
    }
    $ast
}

sub found-bool(@values, $try-again is rw, %bools, CX::Red::Bool $ex) {

    if %bools{$ex.ast}:!exists {
        $try-again = True;
        %bools{ $ex.ast }++;
        if not @values {
            @values.push: [ :{ $ex.ast => $ex.value }, Red::AST ];
        } else {
            my @new-keys = @values.map: -> $item { my %key{Red::AST} = $item.[0].clone; %key{$ex.ast} = $ex.value.succ; %key };
            for @values {
                .[0].{$ex.ast} = $ex.value
            }
            @values.push: |@new-keys.map: -> %key { [ %key, Red::AST ] };
        }
    }
    $ex.resume
}

sub prepare-response($resp) {
    do given $resp {
        when Empty {
            Red::AST::Empty.new
        }
        when Red::AST {
            $_
        }
        default {
            ast-value $_
        }
    }
}

sub what-does-it-do(&func, \type) {
    my Bool $try-again = False;
    my %bools is SetHash;
    my @values;
    my %*VALS := :{};

    my $ret = func type;
    return Red::AST => prepare-response $ret unless $try-again;
    @values.head.[1] = $ret;
    my %first-key := :{ @values.head.[0].keys.head.clone => @values.head.[0].values.head.clone };
    %first-key{ %first-key.keys.head } = True;
    @values.push: [%first-key, Red::AST];

    for @values -> @data (%values, $response is rw) {
        $try-again = False;
        %*VALS := %values;
        $response = func type;
        CONTROL {
            when CX::Next {
                $response = Red::AST::Next.new;
            }
        }
    }
    CATCH {
        when CX::Red::Bool {                # needed until we can create real custom CX
            found-bool @values, $try-again, %bools, $_
        }
    }
    CONTROL {
        when CX::Red::Bool {                # Will work when we can create real custom CX
            found-bool @values, $try-again, %bools, $_
        }
        when CX::Next {
            die
        }
    }

    my Red::AST %values{Red::AST};
    for @values {
        %values{hash-to-cond(.[0])} = prepare-response .[1]
    }
    %values
}

multi method create-map($_, &filter)        { self.do-it.map: &filter }
multi method create-map(Red::Model  $_, &?) { .^where: $.filter }
multi method create-map(Red::AST    $_, &?) {
    require ::("MetamodelX::Red::Model");
    my \Meta  = ::("MetamodelX::Red::Model").WHAT;
    my \model = Meta.new(:table(self.of.^table)).new_type: :name(self.of.^name);
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
    my \model = Meta.new(:table(self.of.^table)).new_type: :name(self.of.^name);
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
    my Red::AST %next{Red::AST};
    my Red::AST %when{Red::AST};
    my %*UPDATE := %!update;
    for what-does-it-do(&filter, self.of) {
        (.value ~~ Red::AST::Next | Red::AST::Empty ?? %next !! %when){.key} = .value
    }
    my $seq = self;
    if %next {
        $seq = self.where(%next.keys.reduce(-> $agg, $n { Red::AST::OR.new: $agg, $n }))
    }
    $seq.create-map: Red::AST::Case.new(:%when), &filter
}
#method flatmap(&filter) {
#    treat-map :flat, $.filter, filter(self.of), &filter
#}

method sort(&order) {
    my @order = order self.of;
    self.clone: :chain($!chain.clone: :@order)
}

method pick(Whatever) {
    self.clone: :chain($!chain.clone: :order[Red::AST::Function.new: :func<random>])
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

method save(::?CLASS:D:) {
    $*RED-DB.execute: Red::AST::Update.new: :into($.table-list.head.^table), :values(%!update), :filter($.filter)
}

method union(::?CLASS:D: $other) {
    my Red::AST $filter = self.ast.union: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

method intersect(::?CLASS:D: $other) {
    my Red::AST $filter = self.ast.intersect: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

method minus(::?CLASS:D: $other) {
    my Red::AST $filter = self.ast.minus: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

method ast {
    if $.filter ~~ Red::AST::MultiSelect {
        $.filter
    } else {
        Red::AST::Select.new: :$.of, :$.filter, :$.limit, :@.order, :@.table-list, :@.group;
    }
}
