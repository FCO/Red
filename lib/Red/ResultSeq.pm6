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
use Red::PrepareCode;
use Red::Phaser;
use Red::ResultSeqMethods;
use Red::Formatter::ResultSeq;
use Red::Formatter::ResultSeq::Vertical;

=head2 Red::ResultSeq

#| Class that represents a Seq of query results
unit role Red::ResultSeq[Mu $of = Any];
also does Sequence;
also does Positional;
also does Red::ResultSeqMethods;

method format(Red::Formatter::ResultSeq:U $formatter = $*RED-FORMATTER-RESULTSEQ // Red::Formatter::ResultSeq::Vertical) {
    $formatter.new(:rs(self)).format
}

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
        %data<block> = .code.?name;
        %data<line>  = .line;
    }
    @!comments.push: Red::AST::Comment.new:
        :msg(
            &*RED-COMMENT-SQL
                ?? &*RED-COMMENT-SQL.(|%data)
                !! comment-sql(|%data)
        )
}

#| Add a comment to SQL query
sub comment-sql(:$meth-name, :$file, :$block, :$line) {
    "method '{ $meth-name // '<anon>' }' called at: { $file // '<none>' } #{ $line // '' }"
}

#| The type of the ResultSeq
method of is hidden-from-sql-commenting { $of }
#method is-lazy { True }
method cache is hidden-from-sql-commenting {
    List.from-iterator: self.iterator
}

has Pair              @.update;
has Red::AST::Comment @.comments;
has Red::Driver       $.with;
has                   $.obj;
has Red::AST::Chained $.chain handles <filter limit offset post order group table-list> .= new: |(:filter(.^id-filter) with $!obj);
has Lock::Async       $!lock .= new;

multi method with { $!with }

multi method with(Red::Driver $with) {
    self.clone: :$with
}

multi method with(Str $with) {
    self.with: %GLOBAL::RED-DEFULT-DRIVERS{$with}
}

method iterator(--> Red::ResultSeq::Iterator) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
    Red::ResultSeq::Iterator.new: :$.of, :$.ast, :&.post, |(:driver($_) with $!with)
}

#| Returns a Seq with the result of the SQL query
method Seq is hidden-from-sql-commenting {
    $!lock.protect: {
        self.create-comment-to-caller;
        Seq.new: self.iterator
    }
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
method grep(&filter) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
    self.create-comment-to-caller;
    CATCH {
        default {
            if !$*RED-FALLBACK.defined || $*RED-FALLBACK {
                if !$*RED-FALLBACK.defined {
                    note "falling back (to mute this message, please define the \$*RED-FALLBACK variable): { .?message }";
                }
                return self.Seq.grep: &filter
            }
            .rethrow
        }
    }
    my $*OUT = class :: {
        method put(|)   { die "Trying to print inside the grep's block" }
        method print(|) { die "Trying to print inside the grep's block" }
    }
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

#multi method create-map($, :&filter)     { self.do-it.map: &filter }
multi method create-map(\SELF: Red::Model $model is copy, :filter(&)) is hidden-from-sql-commenting {
    self but role :: { method of { $model } }
}
multi method create-map(\SELF: *@ret where .all ~~ Red::AST, :&filter) is hidden-from-sql-commenting {
    my @*table-list = |@.table-list, self.of;
    my \model = SELF.of.^specialise(|@ret);
    my role CMModel [Mu:U \m] {
        has &.last-filter = &filter;
        has $.last-rs  = SELF;
        method of { model }
    }
    @*table-list .= unique;
    SELF.clone(
        :chain($!chain.clone:
            :$.filter,
            :post{ my @data = do for model.^columns -> $attr { ."{$attr.name.substr: 2}"() }; @data == 1 ?? @data.head !! |@data },
            :@*table-list,
            |%_
        )
    ) but CMModel[model]
}

#| Change what will be returned (does not run the query)
method map(\SELF: &filter) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
    SELF.create-comment-to-caller;
    CATCH {
        default {
            if !$*RED-FALLBACK.defined || $*RED-FALLBACK {
                if !$*RED-FALLBACK.defined {
                    note "falling back (to mute this message, please define the \$*RED-FALLBACK variable): { .?message }";
                }
                return self.Seq.map: &filter
            }
            .rethrow
        }
    }
    my $*OUT = class :: {
        method put(|)   { die "Trying to print inside the map's block" }
        method print(|) { die "Trying to print inside the map's block" }
    }

    die "Count bigger than 1" if &filter.count > 1;
    my Red::AST %next{Red::AST};
    my Red::AST %when{Red::AST};
    my @*UPDATE := @!update;
    for what-does-it-do(&filter, SELF.of) -> Pair $_ {
        (.value ~~ (Red::AST::Next | Red::AST::Empty) ?? %next !! %when){.key} = .value
    }
    my \seq := do if %next {
        SELF.where(%next.keys.reduce(-> $agg, $n { Red::AST::OR.new: $agg, $n }))
    } else { SELF }
    my \ast = Red::AST::Case.new(:%when);
    #die "Map returning Red::Model is NYI" if ast ~~ Red::AST::Value and ast.type ~~ Red::Model;
    return seq.create-map: ast.value, :&filter if ast ~~ Red::AST::Value and ast.type ~~ Red::Model;
    return seq.create-map: ast.value, :&filter if ast ~~ Red::AST::Value and ast.type ~~ Positional;
    seq.create-map: ast, :&filter
}
#method flatmap(&filter) {
#    treat-map :flat, $.filter, filter(self.of), &filter
#}

#| Defines the order of the query (does not run the query)
method sort(&order --> Red::ResultSeq) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
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
    my $*RED-INTERNAL = True;
    SELF.create-comment-to-caller;
    do if self.?last-rs.DEFINITE {
        self.last-rs.classify(&func o self.last-filter, :as{ ast-value True })
    } else {
        my \key   = func SELF.of;
        my \value = as   SELF.of;
        Red::ResultAssociative[value, key].new: :rs(SELF)
    }
}

#| Runs a query to create a Bag
multi method Bag {
    nextsame unless self.?last-rs.DEFINITE;
    self.last-rs.classify(self.last-filter, :as{ ast-value True }).Bag
}

#| Runs a query to create a Set
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
multi method head(UInt(Numeric) $num) is hidden-from-sql-commenting {
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
    $.of.^orig.^create: |%pars, |%(|(.should-set with $.filter), |(.should-set with $.of.HOW.?join-on: $.of));
}

#| Alias for `create`
method push(::?CLASS:D: *%pars) is hidden-from-sql-commenting {
    $.create(|%pars)
}

#| Deletes every row on that ResultSeq
method delete(::?CLASS:D:) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    get-RED-DB.execute: Red::AST::Delete.new: $.of, $.filter
}

#| Saves any change on any element of that ResultSet
method save(::?CLASS:D:) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my @*UPDATE;
    die "You should use a map updating value(s) before saving" unless $.of.^can: "orig-result-seq";
    $.of.orig-result-seq.of.^apply-row-phasers(BeforeUpdate);
    get-RED-DB.execute: Red::AST::Update.new: :model($.table-list.head), :values[|@!update, |@*UPDATE], :filter($.filter)
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

#| Join (Positional join)
multi method join(Str() $sep) {
    self.Seq.join: $sep
}

#| Create a custom join (SQL join)
method join-model(Red::Model \model, &on, :$name = "{ self.^shortname }_{ model.^shortname }", *%pars where { .elems == 0 || ( .elems == 1 && so .values.head ) }) {
    my $*RED-INTERNAL = True;
    do with self.obj {
        my $filter = do given what-does-it-do(&on.assuming($_), model) {
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
        model.^all.where: $filter
    } else {
        self.of.^join(model, &on, :$name,  |%pars).^all.clone: :$!chain
    }
}

#| Returns the AST that will generate the SQL
method ast(Bool :$sub-select --> Red::AST) is hidden-from-sql-commenting {
    if $.filter ~~ Red::AST::MultiSelect {
        $.filter
    } else {
        my @prefetch = $.of.^has-one-relationships;
        Red::AST::Select.new: :$.of, :$.filter, :$.limit, :$.offset, :@.order, :@.table-list, :@.group, :@.comments, :@prefetch, :$sub-select;
    }
}
