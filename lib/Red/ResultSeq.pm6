use Red::DB;
use Red::AST;
use Red::Utils;
use Red::Model;
use Red::Column;
use Red::Driver;
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

=head2 Red::ResultSeq

unit role Red::ResultSeq[Mu $of = Any] does Sequence;
also does Positional;

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
has Red::Driver       $.with;

multi method with(Red::Driver $with) {
    self.clone: :$with
}

multi method with(Str $with) {
    self.with: %GLOBAL::RED-DEFULT-DRIVERS{$with}
}

method iterator(--> Red::ResultSeq::Iterator) is hidden-from-sql-commenting {
    Red::ResultSeq::Iterator.new: :$.of, :$.ast, :&.post, |(:driver($_) with $!with)
}

        #| Returns a Seq with the result of the SQL query
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

#| Adds a new filter on the query (does not run the query)
method grep(&filter --> Red::ResultSeq) is hidden-from-sql-commenting {
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

#| Changes the query to return only the first row that matches the condition and run it (.grep(...).head)
multi method first(&filter --> Red::Model) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.grep(&filter).head
}

multi method first(--> Red::Model) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.head
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
multi method create-map(\SELF: Red::Model  $_, :filter(&)) is hidden-from-sql-commenting {
    .^where: $.filter
}
multi method create-map(\SELF: *@ret where .all ~~ Red::AST, :&filter) is hidden-from-sql-commenting {
    my \Meta  = SELF.of.HOW.WHAT;
    my \model = Meta.new(:table(SELF.of.^table)).new_type: :name(SELF.of.^name);
    model.HOW.^attributes.first(*.name eq '$!table').set_value: model.HOW, SELF.of.^table;
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
        model.^add_multi_method: $name, my method (Mu:D:) { SELF.get_value: "\$!$name" }
        $attr
    }
    model.^add_method: "no-table", my method no-table { True }
    model.^compose;
    model.^add-column: $_ for @attrs;
    my role CMModel [Mu:U \m] {
        has &.last-filter = &filter;
        has $.last-rs  = SELF;
        method of { model }
    }
    SELF.clone(
        :chain($!chain.clone:
            :$.filter,
            :post{ my @data = do for @attrs -> $attr { ."{$attr.name.substr: 2}"() }; @data == 1 ?? @data.head !! |@data },
            :table-list[(|@.table-list, self.of).unique],
            |%_
        )
    ) but CMModel[model]
}

#| Change what will be returned (does not run the query)
method map(\SELF: &filter --> Red::ResultSeq) is hidden-from-sql-commenting {
    SELF.create-comment-to-caller;
    my Red::AST %next{Red::AST};
    my Red::AST %when{Red::AST};
    my %*UPDATE := %!update;
    for what-does-it-do(&filter, SELF.of) -> Pair $_ {
        (.value ~~ (Red::AST::Next | Red::AST::Empty) ?? %next !! %when){.key} = .value
    }
    my \seq := do if %next {
        SELF.where(%next.keys.reduce(-> $agg, $n { Red::AST::OR.new: $agg, $n }))
    } else { SELF }
    my \ast = Red::AST::Case.new(:%when);
    seq.create-map: ast, :&filter
}
#method flatmap(&filter) {
#    treat-map :flat, $.filter, filter(self.of), &filter
#}

#| Defines the order of the query (does not run the query)
method sort(&order --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my @order = order self.of;
    self.clone: :chain($!chain.clone: :@order)
}

#| Sets the query to return the rows in a randomic order (does not run the query)
multi method pick(Whatever --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone: :chain($!chain.clone: :order[Red::AST::Function.new: :func<random>])
}

multi method pick(Int() $num) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.pick(*).head: |($_ with $num)
}

multi method pick() is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.pick(*).head
}

#| Returns a ResultAssociative classified by the passed code (does not run the query)
method classify(\SELF: &func, :&as = { $_ } --> Red::ResultAssociative) is hidden-from-sql-commenting {
    SELF.create-comment-to-caller;
    do if self.?last-rs.DEFINITE {
        self.last-rs.classify(&func o self.last-filter, :as{ ast-value True })
    } else {
        my \key   = func SELF.of;
        my \value = as   SELF.of;
        Red::ResultAssociative[value, key].new: :rs(SELF)
    }
}

multi method Bag {
    nextsame unless self.?last-rs.DEFINITE;
    self.last-rs.classify(self.last-filter, :as{ ast-value True }).Bag
}

multi method Set {
    nextsame unless self.?last-rs.DEFINITE;
    self.last-rs.classify(self.last-filter, :as{ ast-value True }).Set
}

#| Gets the first row returned by the query (run the query)
multi method head is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.do-it(:1limit).head
}

# TODO: Return a Red::ResultSeq
multi method head(UInt() $num) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone: :chain($!chain.clone: :limit(min $num, $.limit))
}

#| Sets the ofset of the query
method from(UInt:D $num --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone: :chain($!chain.clone: :offset(($.offset // 0) + $num));
}

#| Returns the number of rows returned by the query (runs the query)
method elems( --> Int()) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.create-map(Red::AST::Function.new: :func<count>, :args[ast-value *]).head
}

#| Returns True if there are lines returned by the query False otherwise (runs the query)
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

#| Returns a ResultSeqSeq containing ResultSeq that will return ResultSeqs with $size rows each (do not run the query)
method batch(Int $size --> Red::ResultSeqSeq) {
    Red::ResultSeqSeq.new: :rs(self), :$size
}

#| Creates a new element of that set
method create(::?CLASS:D: *%pars) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    $.of.^create: |%pars, |(.should-set with $.filter);
}

#| Alias for `create`
method push(::?CLASS:D: *%pars) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    $.of.^create: |%pars, |(.should-set with $.filter);
}

#| Deletes every row on that ResultSeq
method delete(::?CLASS:D:) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    get-RED-DB.execute: Red::AST::Delete.new: $.of, $.filter
}

#| Saves any change on any element of that ResultSet
method save(::?CLASS:D:) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    get-RED-DB.execute: Red::AST::Update.new: :into($.table-list.head.^table), :values(%!update), :filter($.filter)
}

#| unifies 2 ResultSeqs
method union(::?CLASS:D: $other --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $filter = self.ast.union: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

#| intersects 2 ResultSeqs
method intersect(::?CLASS:D: $other --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $filter = self.ast.intersect: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

#| Removes 1 ResultSeq elements from other ResultSeq
method minus(::?CLASS:D: $other --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my Red::AST $filter = self.ast.minus: $other.ast;
    self.clone: :chain($!chain.clone: :$filter)
}

#|Returns the AST that will generate the SQL
method ast(Bool :$sub-select --> Red::AST) is hidden-from-sql-commenting {
    if $.filter ~~ Red::AST::MultiSelect {
        $.filter
    } else {
        Red::AST::Select.new: :$.of, :$.filter, :$.limit, :$.offset, :@.order, :@.table-list, :@.group, :@.comments, :$sub-select;
    }
}
