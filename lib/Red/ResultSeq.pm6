use Red::DB;
use Red::AST;
use Red::Utils;
use Red::Column;
use Red::AST::Next;
use Red::AST::Case;
use Red::AST::Empty;
use Red::AST::Value;
use Red::AST::Update;
use Red::AST::Delete;
use Red::AST::Comment;
use Red::Attr::Column;
use Red::AST::Infixes;
use Red::AST::Chained;
use Red::AST::Function;
use Red::AST::Select;
use Red::ResultSeqSeq;
use Red::AST::MultiSelect;
use Red::ResultAssociative;
use Red::ResultSeq::Iterator;
use Red::HiddenFromSQLCommenting;
use X::Red::Exceptions;
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

method create-comment-to-caller is hidden-from-sql-commenting {
    my %data;
    %data<meth-name> = callframe(1).code.name;
    given Backtrace.new.tail(*-3).first: {
        .subname and .subname ne "<anon>" and !.code.?is-hidden-from-sql-commenting
    } {
        %data<file>  = .file;
        %data<block> = .code.name;
        %data<line>  = .line;
    }
    @!comments.push: Red::AST::Comment.new:
        :msg(
            &*RED-COMMENT-SQL
                ?? &*RED-COMMENT-SQL.(|%data)
                !! comment-sql(|%data)
        )
}

sub comment-sql(:$meth-name, :$file, :$block, :$line) {
    "method '$meth-name' called at: { $file } #{ $line }"
}

method of is hidden-from-sql-commenting { $of }
#method is-lazy { True }
method cache is hidden-from-sql-commenting {
    List.from-iterator: self.iterator
}

has Red::AST::Chained $.chain handles <filter limit offset post order group table-list> .= new;
has Red::AST          %.update;
has Red::AST::Comment @.comments;

method iterator is hidden-from-sql-commenting {
    Red::ResultSeq::Iterator.new: :$.of, :$.ast, :&.post
}

method Seq is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    Seq.new: self.iterator
}

method do-it(*%pars) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone(|%pars, :chain($!chain.clone: |%pars)).Seq
}

#multi method grep(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method where(::?CLASS:U: Red::AST:U $filter) is hidden-from-sql-commenting { self.WHAT  }
multi method where(::?CLASS:D: Red::AST:U $filter) is hidden-from-sql-commenting { self.clone }
multi method where(::?CLASS:U: Red::AST:D $filter) is hidden-from-sql-commenting { self.new: :chain($!chain.clone: :$filter) }
multi method where(::?CLASS:D: Red::AST:D $filter) is hidden-from-sql-commenting {
    self.clone: :chain($!chain.clone: :filter(($.filter, $filter).grep({ .defined }).reduce: { Red::AST::AND.new($^a, $^b) }))
}

method transform-item(*%data) is hidden-from-sql-commenting {
    self.of.bless: |%data
}

method grep(&filter) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $*RED-GREP-FILTER;
    my $filter = do given what-does-it-do(&filter, self.of) {
        do if [eqv] .values {
            .values.head
        } else {
            .kv.map(-> $test, $ret {
                do with $test {
                    Red::AST::AND.new: $test, ast-value $ret
                } else {
                    $ret
                }
            }).reduce: { Red::AST::OR.new: $^agg, $^fil }
        }
    }
    with $*RED-GREP-FILTER {
        $filter = Red::AST::AND.new: ($_ ~~ Red::AST ?? $_ !! .&ast-value), $filter
    }
    self.where: $filter;
}
method first(&filter) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.grep(&filter).head
}

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

sub what-does-it-do(&func, \type --> Hash) {
    my Bool $try-again = False;
    my %bools is SetHash;
    my @values;
    my %*VALS := :{};

    my $ret = func type;
    return :{ Red::AST => prepare-response $ret } unless $try-again;
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
            when CX::Red::Bool {                # Will work when we can create real custom CX
                found-bool @values, $try-again, %bools, $_
            }
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

#multi method create-map($, :&filter)     { self.do-it.map: &filter }
multi method create-map(Red::Model  $_, :filter(&)) is hidden-from-sql-commenting { .^where: $.filter }
multi method create-map(*@ret where .all ~~ Red::AST, :filter(&)) is hidden-from-sql-commenting {
    my \Meta  = self.of.HOW.WHAT;
    my \model = Meta.new(:table(self.of.^table)).new_type: :name(self.of.^name);
    model.HOW.^attributes.first(*.name eq '$!table').set_value: model.HOW, self.of.^table;
    my $attr-name = 'data_0';
    my @attrs = do for @ret {
        my $name = $.filter ~~ Red::AST::MultiSelect ?? .attr.name.substr(2) !! ++$attr-name;
        my $col-name = $_ ~~ Red::Column ?? .attr.name.substr(2) !! $name;
        my $attr  = Attribute.new:
            :name("\$!$name"),
            :package(model),
            :type(.returns),
            :has_accessor,
            :build(.returns),
        ;
        my %data = %(
            :name-alias($col-name),
            :name($col-name),
            :attr-name($name),
            :type(.returns.^name),
            :$attr,
            :class(model),
        	|(do if $_ ~~ Red::Column {
        		:inflate(.inflate),
        		:deflate(.deflate),
        	} else {
                :computation($_)
        	})
        );
        $attr does Red::Attr::Column(%data);
        model.^add_attribute: $attr;
        model.^add_multi_method: $name, my method (Mu:D:) { self.get_value: "\$!$name" }
        $attr
    }
    model.^add_method: "no-table", my method no-table { True }
    model.^compose;
    model.^add-column: $_ for @attrs;
    my role CMModel [Mu:U \m] { method of { model } };
    self.clone(
        :chain($!chain.clone:
            :$.filter,
            :post{ my @data = do for @attrs -> $attr { ."{$attr.name.substr: 2}"() }; @data == 1 ?? @data.head !! |@data },
            :table-list[(|@.table-list, self.of).unique],
            |%_
        )
    ) but CMModel[model]
}

method map(&filter) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST %next{Red::AST};
    my Red::AST %when{Red::AST};
    my %*UPDATE := %!update;
    for what-does-it-do(&filter, self.of) -> Pair $_ {
        (.value ~~ (Red::AST::Next | Red::AST::Empty) ?? %next !! %when){.key} = .value
    }
    my $seq = self;
    if %next {
        $seq = self.where(%next.keys.reduce(-> $agg, $n { Red::AST::OR.new: $agg, $n }))
    }
    $seq.create-map: Red::AST::Case.new(:%when), :filter(&filter)
}
#method flatmap(&filter) {
#    treat-map :flat, $.filter, filter(self.of), &filter
#}

method sort(&order) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my @order = order self.of;
    self.clone: :chain($!chain.clone: :@order)
}

method pick(Whatever) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone: :chain($!chain.clone: :order[Red::AST::Function.new: :func<random>])
}

method classify(&func, :&as = { $_ }) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my $key   = func self.of;
    my $value = as   self.of;
    Red::ResultAssociative[$value, $key].new: :rs(self)
}

multi method head is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.do-it(:1limit).head
}

multi method head(UInt:D $num) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.do-it(:limit(min $num, $.limit)).head: $num
}

method from(UInt:D $num) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone: :chain($!chain.clone: :offset(($.offset // 0) + $num));
}

method elems( --> Int()) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.create-map(Red::AST::Function.new: :func<count>, :args[ast-value *]).head
}

method Bool( --> Bool()) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.create-map(Red::AST::Gt.new: Red::AST::Function.new(:func<count>, :args[ast-value *]), ast-value 0).head
}

method new-object(::?CLASS:D: *%pars) is hidden-from-sql-commenting {
    my %data = $.filter.should-set;
    my \obj = self.of.bless;#: |%pars, |%data;
    for %(|%pars, |%data).kv -> $key, $val {
        obj.^set-attr: $key, $val
    }
    obj
}

method batch(Int $size) {
    Red::ResultSeqSeq.new: :rs(self), :$size
}

method create(::?CLASS:D: *%pars) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    $.of.^create: |%pars, |(.should-set with $.filter);
}

method delete(::?CLASS:D:) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    get-RED-DB.execute: Red::AST::Delete.new: $.of, $.filter
}

method save(::?CLASS:D:) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    get-RED-DB.execute: Red::AST::Update.new: :into($.table-list.head.^table), :values(%!update), :filter($.filter)
}

method union(::?CLASS:D: $other) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $filter = self.ast.union: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

method intersect(::?CLASS:D: $other) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $filter = self.ast.intersect: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

method minus(::?CLASS:D: $other) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $filter = self.ast.minus: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

method ast(Bool :$sub-select) is hidden-from-sql-commenting {
    if $.filter ~~ Red::AST::MultiSelect {
        $.filter
    } else {
        Red::AST::Select.new: :$.of, :$.filter, :$.limit, :$.offset, :@.order, :@.table-list, :@.group, :@.comments, :$sub-select;
    }
}
