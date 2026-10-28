use Red::DB;
use Red::AST;
use Red::Utils;
use Red::Model;
use Red::Column;
use Red::Driver;
use Red::QueryPlan::Cache;
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
use Red::Compiler::Template;
use Red::Phaser;
use Red::ResultSeqMethods;
use Red::Formatter::ResultSeq;
use Red::Formatter::ResultSeq::Vertical;
use Red::LockType;
use Red::Projection;
use Red::Type::Json;
use Red::AST::Reference;
use Red::AST::ProjectionField;
use Red::AST::Ordering;
use Red::AST::ProductSource;
use MetamodelX::Red::VirtualView;

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
# Queries built in a transaction must not silently switch to the caller's driver
# when evaluated later. Outside transactions, retain the usual unbound behavior.
has Red::Driver       $.with = do {
    my $driver = try get-RED-DB;
    $driver.defined && $driver.^can('transaction-guard') ?? $driver !! Red::Driver
};
has                   $.obj;
has Red::AST::Chained $.chain handles <filter limit offset post order group table-list> .= new: |(:filter(.^id-filter) with $!obj);
has Lock::Async       $!lock .= new;
has Red::QueryPlan::Cache $!query-plan-cache .= new;
has Red::LockType     $.for;
has                   @.prefetches;
has Bool              $.prefetches-set = False;

multi method with { $!with }

multi method with(Red::Driver $with) {
    self.clone: :$with
}

multi method with(Str $with) {
    self.with: %GLOBAL::RED-DEFAULT-DRIVERS{$with}
}

method iterator(--> Red::ResultSeq::Iterator) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
    Red::ResultSeq::Iterator.new: :$.of, :$.ast, :&.post,
        :plan-cache($!query-plan-cache), |(:driver($_) with $!with)
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

method skip-locked {
    self.clone: :for(SKIP_LOCKED)
}

#multi method grep(::?CLASS: &filter) { nextwith :filter( filter self.of.^alias: "me" ) }
multi method where(::?CLASS:U: Red::AST:U $filter) is hidden-from-sql-commenting { self.WHAT  }
multi method where(::?CLASS:D: Red::AST:U $filter) is hidden-from-sql-commenting { self.clone }
multi method where(::?CLASS:U: Red::AST:D $filter) is hidden-from-sql-commenting { self.new: :chain($!chain.clone: :$filter) }
multi method where(::?CLASS:D: Red::AST:D $filter) is hidden-from-sql-commenting {
    self.clone: :chain($!chain.clone: :filter(($.filter, $filter).grep({ .defined }).reduce: -> $a, $b? {
        $b.DEFINITE ?? Red::AST::AND.new($a, $b) !! $a
    }))
}

method transform-item(*%data) is hidden-from-sql-commenting {
    self.of.bless: |%data
}

#| Builds one SQL statement for a product of queries and captured value collections.
method cross-product(@inputs) {
    my $driver = self.with // get-RED-DB;
    my @sources;
    my @shapes;
    my @order;
    my @identity;
    my Red::AST $filter;
    my Bool $identity-lost = False;
    for @inputs -> $input {
        my $alias = Red::Projection.allocate-alias;
        my $shape;
        if $input ~~ Red::ResultSeq {
            X::Red::Projection.new(:reason('Product inputs must share one driver instance')).throw
                unless ($input.with // get-RED-DB) === $driver;
            X::Red::Projection.new(:reason('Products do not support updating maps or row locks')).throw
                if $input.update.elems || $input.for.DEFINITE;
            my @input-identity = do {
                if $input.chain.identity-lost || $input.group.elems { () }
                elsif $input.chain.row-identity.elems { $input.chain.row-identity }
                elsif $input.chain.projection.DEFINITE { () }
                else { $input.of.^id.map(*.column) }
            };
            $identity-lost ||= !@input-identity.elems;
            my $query = $input.ast;
            X::Red::Projection.new(:reason('Product inputs require SELECT queries')).throw
                unless $query ~~ Red::AST::Select;
            X::Red::Projection.new(:reason('Products do not support prefetched inputs')).throw
                if $query.prefetch.elems;
            if !$input.chain.projection.DEFINITE && !$input.chain.source.DEFINITE
                && !$input.chain.sources.elems && !$input.limit.DEFINITE
                && !$input.offset.DEFINITE && !$input.group.elems
                && (!$input.filter.DEFINITE || Red::Projection.safe-to-repeat($input.filter))
                && $input.order.map({ Red::Projection.safe-to-repeat($_) }).all
                && !($input.of.HOW ~~ MetamodelX::Red::VirtualView)
                && !$query.tables.grep({ $_ !=== $input.of }).elems {
                my $model = $input.of.^orig.^alias($alias);
                $model.HOW does role { method tables(\type) { [type] } };
                my @old = $input.of.^columns.map(*.column);
                my @new = $model.^columns.map(*.column);
                sub rebind(Red::AST $expression) {
                    my $result = $expression;
                    for @old.kv -> $i, $column {
                        $result = $result.replace($column, @new[$i]);
                    }
                    $result
                }
                if $input.filter.DEFINITE {
                    my $condition = rebind($input.filter);
                    $filter = $filter.DEFINITE
                        ?? Red::AST::AND.new($filter, $condition) !! $condition;
                }
                @order.append: $input.order.map({ rebind($_) });
                @identity.append: @input-identity.map({ rebind($_) });
                @sources.push: Red::AST::ProductSource.new(:$alias, :$model);
                @shapes.push: Red::Projection.from-value($model);
                next;
            }
            $shape = $input.chain.projection.DEFINITE
                ?? $input.chain.projection !! Red::Projection.from-value($input.of);
            my @columns = $input.of.^columns;
            my @leaves = $shape.leaves;
            my @fields = $query.fields;
            my @references = @leaves.kv.map(-> $i, $leaf {
                my $column = @columns[$i].column;
                my Red::AST $presence;
                if $column.returns ~~ Json {
                    my $name = "red_product_presence_$i";
                    @fields.push: Red::AST::ProjectionField.new(
                        :value(Red::Projection.json-presence($leaf)), :$name);
                    $presence = Red::AST::Reference.new(:table($alias), :$name, :type(Bool));
                }
                Red::AST::Reference.new(:table($alias), :name($column.attr-name), :$presence,
                    :undefined-type($leaf.^can('undefined-type') ?? $leaf.undefined-type !! Mu),
                    :custom-inflate(so $leaf.?custom-inflate
                        || ($leaf ~~ Red::Column && (so $leaf.attr.args<inflate>:exists
                            || ($leaf.returns.HOW ~~ Metamodel::ClassHOW
                                && so $leaf.returns.^can('inflator'))))),
                    :type($column.returns), :inflate($column.inflate), :deflate($column.deflate))
                    but ::('Red::ColumnMethods')
            });
            for $input.order.kv -> $i, $expression {
                my $ordering = Red::AST::Ordering.from-expression($expression);
                my $name = "red_product_order_$i";
                @fields.push: Red::AST::ProjectionField.new(:value($ordering.value), :$name);
                @order.push: $ordering.clone(:value(Red::AST::Reference.new(
                    :table($alias), :$name, :type($ordering.returns))));
            }
            for @input-identity.kv -> $i, $expression {
                my $name = "red_product_identity_$i";
                @fields.push: Red::AST::ProjectionField.new(:value($expression), :$name);
                @identity.push: Red::AST::Reference.new(
                    :table($alias), :$name, :type($expression.returns));
            }
            @sources.push: Red::AST::ProductSource.new(:$alias,
                :query($query.clone(:@fields)));
            $shape = $shape.replace-leaves(@references);
        } else {
            my @shapes = $input.map({ Red::Projection.from-value($_) });
            $shape = @shapes.head // Red::Projection.from-value(Any);
            X::Red::Projection.new(:reason('Product values must have a uniform shape')).throw
                unless @shapes.map(*.signature).all eq $shape.signature;
            my @types = $shape.leaves.map(*.returns);
            my @undefined = Mu xx @types.elems;
            for @shapes -> $row {
                for $row.leaves.kv -> $i, $leaf {
                    unless $leaf.value.DEFINITE {
                        X::Red::Projection.new(:reason('Nullable product values must share one type')).throw
                            if @undefined[$i] !=== Mu && @undefined[$i] !=== $leaf.returns;
                        @undefined[$i] = $leaf.returns;
                        next;
                    }
                    @types[$i] = $leaf.returns unless @types[$i] !=== Any;
                    X::Red::Projection.new(:reason('Product values must have uniform leaf types')).throw
                        unless $leaf.returns === @types[$i];
                }
            }
            my Int $null-index = 0;
            $shape = $shape.with-undefined-types(@undefined, $null-index);
            my @names = |(^@types.elems).map({ "value_$_" }), 'ordinal';
            my @rows = @shapes.kv.map(-> $i, $row {
                [|$row.leaves.map(*.value), $i]
            });
            @sources.push: Red::AST::ProductSource.new(:$alias, :@rows, :@names,
                :types[|@types, Int]);
            $shape = $shape.replace-leaves(@types.kv.map(-> $i, $type {
                Red::AST::Reference.new(:table($alias), :name("value_$i"), :$type,
                    :undefined-type(@undefined[$i]),
                    :inflate(Red::Projection.literal-inflator($type)),
                    :deflate(*.self))
                    but ::('Red::ColumnMethods')
            }));
            my $ordinal = Red::AST::Reference.new(:table($alias), :name<ordinal>, :type(Int));
            @identity.push: $ordinal;
            @order.push: Red::AST::Ordering.from-expression($ordinal);
        }
        @shapes.push: $shape;
    }
    my $projection = Red::Projection.new(:kind<list>, :children(@shapes));
    my @expressions = $projection.leaves;
    @expressions = ast-value(1) unless @expressions;
    my @*table-list;
    my $model = self.of.^specialise(|@expressions);
    my @columns = $model.^columns;
    my role ProductModel[Mu:U \m] { method of { m } }
    self.clone(:with($driver), :chain(Red::AST::Chained.new(
        :@sources, :$projection, :@order, :$filter, :$identity-lost, :row-identity(@identity),
        :post(-> $row { $projection.construct(@columns.map({ .get_value($row) })) })
    ))) but ProductModel[$model]
}

#| The symbolic element passed to a block, independently of the storage model.
method !projection-subject() {
    return self.of unless $!chain.projection.DEFINITE;
    $!chain.projection.construct($!chain.projection.leaves.map({
        $_ ~~ ::('Red::ColumnMethods') ?? $_ !! $_ but ::('Red::ColumnMethods')
    }))
}

#| Exports a projection or a pagination barrier as a derived table.
method !can-fuse-projection(--> Bool:D) {
    so $!chain.projection.DEFINITE && !$.limit.DEFINITE && !$.offset.DEFINITE
        && !$.group.elems
        && $!chain.projection.leaves.map({ Red::Projection.safe-to-repeat($_) }).all
}

method !row-identity {
    return () if $!chain.identity-lost || $.group.elems;
    return $!chain.row-identity if $!chain.row-identity.elems;
    return () if $!chain.projection.DEFINITE;
    self.of.^id.map(*.column)
}

method !projection-input(Bool :$fuse = False, Bool :$preserve-order = True) {
    return self if $fuse && self!can-fuse-projection;
    return self unless $!chain.projection.DEFINITE || $.limit.DEFINITE || $.offset.DEFINITE;
    return self if $!chain.projection-bound && !$.limit.DEFINITE && !$.offset.DEFINITE;
    X::Red::Projection.new(:reason("An updating map cannot be used as a SQL projection")).throw
        if @!update;
    my $depth = $!chain.projection-depth + 1;
    my $alias = Red::Projection.allocate-alias;
    my $source = self.ast;
    my @fields;
    my @order = $preserve-order ?? $.order.kv.map(-> $i, $expression {
        my $ordering = Red::AST::Ordering.from-expression($expression);
        my $name = "red_order_$i";
        @fields.push: Red::AST::ProjectionField.new(:value($ordering.value), :$name);
        $ordering.clone(:value(Red::AST::Reference.new(
            :table($alias), :$name, :type($ordering.returns))))
    }) !! ();
    my @row-identity = self!row-identity.kv.map(-> $i, $expression {
        my $name = "red_identity_$i";
        @fields.push: Red::AST::ProjectionField.new(:value($expression), :$name);
        Red::AST::Reference.new(:table($alias), :$name, :type($expression.returns))
    });
    my $exported = @fields.elems;
    $source = $source.clone(:fields[|$source.fields, |@fields]);
    my $model;
    my $projection = $!chain.projection;
    if $projection.DEFINITE {
        my @columns = self.of.^columns;
        my @leaves = $projection.leaves;
        my @references = do for @columns.kv -> $i, $attr {
            my $column = $attr.column;
            my Red::AST $presence;
            if $attr.type ~~ Json {
                my $expression = Red::Projection.json-presence(@leaves[$i]);
                my $name = "{$alias}_presence_$i";
                @fields.push: Red::AST::ProjectionField.new(:value($expression), :$name);
                $presence = Red::AST::Reference.new(:table($alias), :$name, :type(Bool));
            }
            Red::AST::Reference.new(:table($alias), :name($column.attr-name), :$presence,
                :custom-inflate(@leaves[$i] ~~ Red::AST
                    && so @leaves[$i].transpose-grep(-> $node {
                    so $node.?custom-inflate || ($node ~~ Red::Column
                        && (so ($node.attr.?args // {})<inflate>:exists
                            || ($node.returns.HOW ~~ Metamodel::ClassHOW
                                && so $node.returns.^can('inflator'))))
                }).elems),
                :type($attr.type), :inflate($column.inflate), :deflate($column.deflate),
                :undefined-type(@leaves[$i].^can('undefined-type')
                    ?? @leaves[$i].undefined-type !! Mu))
                but ::('Red::ColumnMethods')
        };
        $source = $source.clone(:fields[|$source.fields, |@fields.skip($exported)]);
        $projection = $projection.replace-leaves(@references);
        $model = self.of.^specialise(|@references);
    } else {
        my @exports;
        for self.of.^columns -> $attr {
            my $column = $attr.column;
            @exports.push: Red::AST::ProjectionField.new(:value($column), :name($column.name))
                if $column.name ne $column.attr-name;
        }
        $source = $source.clone(:fields[|$source.fields, |@exports]);
        $model = self.of.^orig.^alias($alias);
        $model.HOW does role { method tables(\type) { [type] } };
    }
    my &post = $!chain.post;
    if $projection.DEFINITE {
        my @columns = $model.^columns;
        &post = -> $row {
            $projection.construct(@columns.map({ .get_value($row) }))
        };
    }
    my role ProjectionModel[Mu:U \m] { method of { m } }
    self.clone(:chain(Red::AST::Chained.new:
        :$source, :source-alias($alias), :$projection, :projection-bound,
        :projection-depth($depth), :@order, :&post,
        :@row-identity, :identity-lost($!chain.identity-lost || so $.group.elems)
    )) but ProjectionModel[$model]
}

method !create-projection(Red::Projection:D $projection, &filter) {
    my @*table-list = |$.table-list, self.of;
    my @expressions = $projection.leaves;
    @expressions = ast-value(1) unless @expressions;
    my $model = self.of.^specialise(|@expressions);
    my @columns = $model.^columns;
    my $previous = self;
    my $aggregate = @expressions.grep({
        .transpose-grep(-> $node {
            $node ~~ Red::AST::Function
                && $node.func.uc eq any(<COUNT MIN MAX SUM AVG DISTINCT>)
        }).elems
    }).elems;
    my role ProjectedModel[Mu:U \m] {
        method of { m }
        has &.last-filter = &filter;
        has $.last-rs = $previous;
    }
    my @tables = @*table-list.unique;
    my @row-identity = self!row-identity;
    self.clone(:chain($!chain.clone:
        :$projection, :!projection-bound, :table-list(@tables),
        :row-identity($aggregate ?? [] !! @row-identity),
        :identity-lost($!chain.identity-lost || so $aggregate || so $.group.elems),
        |(:order([]) if $aggregate),
        :post(-> $row {
            my @values = @columns.map({ .get_value($row) });
            $projection.construct(@values)
        })
    )) but ProjectedModel[$model]
}

#| Resolve a compiled callback against the current SQL stage, retaining legacy fallback.
method !query-block(&callback, $compiled is rw, $subject, Bool :$ordering = False,
    Bool :$cache-filter = False, :$diagnostic, Str:D :$method!, Bool :$warned! is rw) {
    my $reason = 'No RakuAST template was supplied';
    if $compiled.DEFINITE {
        my $unsupported = False;
        my Red::AST %branches{Red::AST};
        try {
            $compiled.validate-callback(&callback);
            my $driver = $!with.DEFINITE ?? $!with !! (try get-RED-DB);
            $driver.?check-regex-support if $compiled.?regex-query;
            $compiled = $compiled.bind($subject) unless $compiled.bound;
            my $cached = $cache-filter ?? $compiled.cached-filter($subject,
                :driver($!with.DEFINITE ?? $!with !! (try get-RED-DB))) !! Nil;
            if $cached.DEFINITE {
                %branches{Red::AST} = $cached;
            } else {
                %branches = $compiled.branches($subject);
            }
            CATCH {
                when X::Red::Compiler::Unsupported {
                    .rethrow if .fatal || $compiled.?regex-query;
                    $unsupported = True;
                    $reason = .reason;
                    my $report = DYNAMIC::<$*RED-COMPILER-REPORT>;
                    $report(:status<fallback>, :reason(.reason)) if $report ~~ Callable;
                }
            }
        }
        return %branches unless $unsupported;
        $compiled = Any;
    }
    self!compiler-warning(&callback, $diagnostic, $method, $reason, $warned);
    if $ordering {
        my Red::AST %branches{Red::AST};
        %branches{Red::AST} = ast-value(callback($subject));
        return %branches;
    }
    what-does-it-do(&callback, $subject).Hash
}

method !compiler-warning(&callback, $diagnostic, Str:D $method, Str:D $reason,
    Bool $warned is rw) {
    return if $warned;
    $warned = emit-compiler-warning(&callback, $diagnostic, :$method, :$reason);
    Nil
}

#| Adds a new filter on the query (does not run the query)
method grep(&filter, :$red-ast is copy) is hidden-from-sql-commenting {
    X::Red::NoOperatorsDefined.new(:meth<grep>).throw
        if !$*from-first && !::CALLERS::<&__RED_OPERATOR_LOADED__> && !::CALLERS::OUTERS::<&__RED_OPERATOR_LOADED__> && !$*RED-DONT-FAIL-WITHOUT-OPERATORS;
    my $*RED-INTERNAL = True;
    self.create-comment-to-caller;
    CATCH {
        default {
            .rethrow if ($red-ast.DEFINITE && $red-ast.?regex-query)
                || ($_ ~~ X::Red::Compiler::Unsupported && .fatal);
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
    my $diagnostic = $red-ast;
    my Bool $warned = False;
    my $input = self!projection-input(:fuse);
    my Red::AST %branches{Red::AST} = self!query-block(
        &filter, $red-ast, $input!projection-subject, :cache-filter,
        :$diagnostic, :method<grep>, :$warned);
    if self.chain.projection.DEFINITE && $input === self
        && !Red::Projection.safe-to-repeat(%branches) {
        $input = self!projection-input;
        %branches = self!query-block(
            &filter, $red-ast, $input!projection-subject, :cache-filter,
            :$diagnostic, :method<grep>, :$warned);
    }
    my $filter = do given %branches {
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
    $input.where: $filter;
}

#| Changes the query to return only the first row that matches the condition and run it (.grep(...).head)
multi method first(&filter, :$red-ast) is hidden-from-sql-commenting {
    X::Red::NoOperatorsDefined.new(:meth<first>).throw
        if !::CALLERS::<&__RED_OPERATOR_LOADED__> && !::CALLERS::OUTERS::<&__RED_OPERATOR_LOADED__> && !$*RED-DONT-FAIL-WITHOUT-OPERATORS;
    self.create-comment-to-caller;
    my $*from-first = True;
    self.grep(&filter, :$red-ast).head
}

multi method first() is hidden-from-sql-commenting {
    X::Red::NoOperatorsDefined.new(:meth<grep>).throw
        if !::CALLERS::<&__RED_OPERATOR_LOADED__> && !::CALLERS::OUTERS::<&__RED_OPERATOR_LOADED__> && !$*RED-DONT-FAIL-WITHOUT-OPERATORS;
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
        method of { m }
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
method map(\SELF: &filter, :$red-ast is copy) is hidden-from-sql-commenting {
    X::Red::NoOperatorsDefined.new(:meth<map>).throw
        if !::CALLERS::<&__RED_OPERATOR_LOADED__> && !::CALLERS::OUTERS::<&__RED_OPERATOR_LOADED__> && !$*RED-DONT-FAIL-WITHOUT-OPERATORS;
    my $*RED-INTERNAL = True;
    SELF.create-comment-to-caller;
    CATCH {
        default {
            .rethrow if ($red-ast.DEFINITE && $red-ast.?regex-query)
                || ($_ ~~ X::Red::Compiler::Unsupported && .fatal);
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
    my $input = SELF!projection-input(:fuse);
    my $diagnostic = $red-ast;
    my Bool $warned = False;
    my @updates = @!update;
    my @*UPDATE := @updates;
    my Red::AST %branches{Red::AST} = self!query-block(
        &filter, $red-ast, $input!projection-subject, :$diagnostic, :method<map>, :$warned);
    if $!chain.projection.DEFINITE && $input === SELF
        && !Red::Projection.safe-to-repeat(%branches) {
        $input = SELF!projection-input;
        @updates = @!update;
        %branches = self!query-block(
            &filter, $red-ast, $input!projection-subject, :$diagnostic, :method<map>, :$warned);
    }
    for %branches -> Pair $_ {
        (.value ~~ (Red::AST::Next | Red::AST::Empty) ?? %next !! %when){.key} = .value
    }
    my \seq := do if %next {
        my @keep = %when.keys;
        $input.where(@keep ?? @keep.reduce(-> $agg, $n? {
            $n.DEFINITE ?? Red::AST::OR.new($agg, $n) !! $agg
        }) !! ast-value(False))
    } else { $input }
    return seq!create-projection(Red::Projection.from-value(Any), &filter) unless %when;
    if @updates.elems == @!update.elems {
        my $model-return = %when.elems == 1 && %when.values.head ~~ Red::AST::Value
            && %when.values.head.type ~~ Red::Model;
        return seq!create-projection(Red::Projection.from-branches(%when), &filter)
            unless $model-return && !$!chain.projection.DEFINITE;
    } else {
        X::Red::Projection.new(:reason("Projected values cannot be updated")).throw
            if $!chain.projection.DEFINITE || $input.chain.source.DEFINITE;
    }
    my $mutable-seq = seq.clone(:update(@updates));
    my \ast = Red::AST::Case.new(:%when);
    #die "Map returning Red::Model is NYI" if ast ~~ Red::AST::Value and ast.type ~~ Red::Model;
    return $mutable-seq.create-map: ast.value, :&filter if ast ~~ Red::AST::Value and ast.type ~~ Red::Model;
    return $mutable-seq.create-map: ast.value, :&filter if ast ~~ Red::AST::Value and ast.type ~~ Positional;
    $mutable-seq.create-map: ast, :&filter
}
#method flatmap(&filter) {
#    treat-map :flat, $.filter, filter(self.of), &filter
#}

#| Orders scalar projected values without executing the query.
multi method sort(--> Red::ResultSeq) is hidden-from-sql-commenting {
    X::Red::Projection.new(:reason(
        "Sorting without a Callable requires a scalar projection"
    )).throw unless $!chain.projection.DEFINITE && $!chain.projection.kind eq 'leaf';
    self.sort({ $_ })
}

#| Defines the order of the query (does not run the query)
multi method sort(&order, :$red-ast is copy --> Red::ResultSeq) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
    self.create-comment-to-caller;
    my $diagnostic = $red-ast;
    my Bool $warned = False;
    my $input = self!projection-input(:fuse);
    my @order = do if $red-ast.DEFINITE {
        my $value = self!query-block(&order, $red-ast, $input!projection-subject,
            :ordering, :$diagnostic, :method<sort>, :$warned).values.head;
        $value ~~ Red::AST::Value ?? $value.value !! $value
    } else {
        self!compiler-warning(&order, $diagnostic, 'sort',
            'No RakuAST template was supplied', $warned);
        order $input!projection-subject
    };
    if $!chain.projection.DEFINITE && $input === self
        && !Red::Projection.safe-to-repeat(@order) {
        $input = self!projection-input;
        @order = do if $red-ast.DEFINITE {
            my $value = self!query-block(&order, $red-ast, $input!projection-subject,
                :ordering, :$diagnostic, :method<sort>, :$warned).values.head;
            $value ~~ Red::AST::Value ?? $value.value !! $value
        } else {
            self!compiler-warning(&order, $diagnostic, 'sort',
                'No RakuAST template was supplied', $warned);
            order $input!projection-subject
        };
    }
    $input.clone: :chain($input.chain.clone: :@order)
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
method classify(\SELF: &func, :&as = { $_ }, :&reduce --> Red::ResultAssociative) is hidden-from-sql-commenting {
    my $*RED-INTERNAL = True;
    SELF.create-comment-to-caller;
    if $!chain.projection.DEFINITE {
        my $input = SELF!projection-input;
        my $subject = $input!projection-subject;
        my $key = func $subject;
        my @keys = $key ~~ Red::AST ?? ($key,) !! $key ~~ Positional
            ?? $key.list !! (ast-value($key),);
        my $value = as $subject;
        return Red::ResultAssociative[$value, @keys.head].new(:rs($input),
            |(:next-level(@keys.skip) if @keys.elems > 1), |(:&reduce if &reduce));
    }
    do if self.?last-rs.DEFINITE {
        self.last-rs.classify(&func o self.last-filter, :as{ ast-value True })
    } else {
        # TODO: use what-does-it-do() for &func, &as and &reduce
        my $key = func SELF.of;
        my @keys = $key ~~ Red::AST ?? ($key,) !! $key ~~ Positional
            ?? $key.list !! (ast-value($key),);
        my $value = as SELF.of;
        Red::ResultAssociative[$value, @keys.head].new(:rs(SELF),
            |(:next-level(@keys.skip) if @keys.elems > 1), |(:&reduce if &reduce))
    }
}

#| Runs a query to create a Bag
multi method Bag {
    return self.classify({ $_ }, :as{ ast-value True }).Bag if $!chain.projection.DEFINITE;
    nextsame unless self.?last-rs.DEFINITE;
    self.last-rs.classify(self.last-filter, :as{ ast-value True }).Bag
}

#| Runs a query to create a Set
multi method Set {
    return self.classify({ $_ }, :as{ ast-value True }).Set if $!chain.projection.DEFINITE;
    nextsame unless self.?last-rs.DEFINITE;
    self.last-rs.classify(self.last-filter, :as{ ast-value True }).Set
}

#| Gets the first row returned by the query (run the query)
multi method head is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.do-it(:limit(min(1, $.limit))).head
}

#| Returns a ResultSeq that gets the first N rows returned by the query
multi method head(UInt(Numeric) $num) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    self.clone: :chain($!chain.clone: :limit(min $num, $.limit))
}

method !ordered-input(Str:D $operation) {
    my $input = self;
    unless $.order.elems {
        my @identity = self!row-identity;
        X::Red::Projection.new(:reason(
            "$operation requires explicit ordering or a preserved primary key"
        )).throw unless @identity;
        $input = self.clone(:chain($!chain.clone(:order(@identity))));
    }
    $input!projection-input(:fuse)
}

#| Reverses the query order without executing it.
method reverse() is hidden-from-sql-commenting {
    my $input;
    my Exception $error;
    try {
        $input = self!ordered-input('reverse');
        CATCH { default { $error = $_ } }
    }
    if $error.DEFINITE {
        $error.rethrow if $*RED-FALLBACK.defined && !$*RED-FALLBACK;
        return self.Seq.reverse;
    }
    my @order = $input.order.map({ Red::AST::Ordering.from-expression($_).reversed });
    $input.clone(:chain($input.chain.clone(:@order)))
}

#| Selects the last rows in their original order without executing the query.
multi method tail(UInt(Numeric) $num) is hidden-from-sql-commenting {
    my $input;
    my Exception $error;
    try {
        $input = self!ordered-input('tail');
        CATCH { default { $error = $_ } }
    }
    if $error.DEFINITE {
        $error.rethrow if $*RED-FALLBACK.defined && !$*RED-FALLBACK;
        return self.Seq.tail($num);
    }
    my @order = $input.order.map({ Red::AST::Ordering.from-expression($_).reversed });
    my $last = $input.clone(:chain($input.chain.clone(:@order, :limit($num))));
    $last = $last!projection-input;
    @order = $last.order.map({ Red::AST::Ordering.from-expression($_).reversed });
    $last.clone(:chain($last.chain.clone(:@order)))
}

multi method tail() is hidden-from-sql-commenting {
    self.tail(1).head
}

multi method tail(&count) is hidden-from-sql-commenting {
    self.Seq.tail(&count)
}

#| Skips the $num first items from ResultSeq (adds a limit on the SQL query)
method skip(UInt:D $num --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my $limit = $.limit;
    $limit = max(0, $limit - $num) if $limit.DEFINITE;
    self.clone: :chain($!chain.clone:
        :offset(($.offset // 0) + $num), :$limit);
}

# Alias for skip. It's going to be deprecated on a future version
method from(UInt:D $num --> Red::ResultSeq) is hidden-from-sql-commenting {
    self.skip: $num
}

method !reduce-projection(Str:D $function) {
    my $projection = $!chain.projection;
    unless $projection.DEFINITE && $projection.kind eq 'leaf'
        && so (Int, UInt, Num, Rat, Numeric).map({
            $_ =:= $projection.expression.returns
        }).any
        && !$projection.expression.transpose-grep(-> $node {
            so $node.?custom-inflate
                || ($node ~~ Red::AST::Value && !$node.value.DEFINITE)
                || ($node ~~ Red::Column
                    && (so ($node.attr.?args // {})<inflate>:exists
                        || ($node.returns.HOW ~~ Metamodel::ClassHOW
                                && so $node.returns.^can('inflator'))))
        }).elems {
        X::Red::Projection.new(:reason(
            "$function requires a numeric scalar projection without nulls or custom inflators"
        )).throw
            if $*RED-FALLBACK.defined && !$*RED-FALLBACK;
        return self.Seq."{$function.lc}"();
    }
    my $result;
    my Exception $error;
    try {
        my $input = self!projection-input(:!preserve-order);
        my $expression = $input.chain.projection.expression;
        my $aggregate = Red::AST::Function.new(:func($function), :args[$expression],
            :returns($expression.returns));
        my @values = $input.clone(:chain($input.chain.clone(:order([]))))
            .create-map($aggregate,
                Red::AST::Function.new(:func<COUNT>, :args[ast-value *], :returns(Int)),
                Red::AST::Function.new(:func<COUNT>, :args[$expression], :returns(Int))
            ).head.list;
        X::Red::Projection.new(:reason(
            "$function cannot preserve native reduction of undefined numeric values"
        )).throw if @values[1] != @values[2];
        $result = @values[0];
        CATCH { default { $error = $_ } }
    }
    if $error.DEFINITE {
        $error.rethrow if $*RED-FALLBACK.defined && !$*RED-FALLBACK;
        return self.Seq."{$function.lc}"();
    }
    $result // ($function eq 'SUM' ?? 0 !! $function eq 'MIN' ?? Inf !! -Inf)
}

multi method sum() is hidden-from-sql-commenting { self!reduce-projection('SUM') }
multi method min() is hidden-from-sql-commenting { self!reduce-projection('MIN') }
multi method max() is hidden-from-sql-commenting { self!reduce-projection('MAX') }

#| Returns the number of rows returned by the query (runs the query)
method elems( --> Int()) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my $input = self!projection-input;
    $input.clone(:chain($input.chain.clone(:order([]))))
        .create-map(Red::AST::Function.new: :func<count>, :args[ast-value *]).head
}

#| Returns True if there are lines returned by the query False otherwise (runs the query)
method Bool( --> Bool()) is hidden-from-sql-commenting {
    self.create-comment-to-caller;
    my $input = self!projection-input;
    $input.clone(:chain($input.chain.clone(:order([]))))
        .create-map(Red::AST::Gt.new: Red::AST::Function.new(:func<count>, :args[ast-value *]), ast-value 0).head
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
    X::Red::Projection.new(:reason("Projected values cannot be used to create rows")).throw
        if $!chain.projection.DEFINITE || $!chain.source.DEFINITE;
    self.create-comment-to-caller;
    $.of.^orig.^create: |%pars, |%(|(.should-set with $.filter), |(.should-set with $.of.HOW.?join-on: $.of));
}

#| Alias for `create`
method push(::?CLASS:D: *%pars) is hidden-from-sql-commenting {
    $.create(|%pars)
}

#| Deletes every row on that ResultSeq
method delete(::?CLASS:D:) is hidden-from-sql-commenting {
    X::Red::Projection.new(:reason("Projected values cannot be deleted")).throw
        if $!chain.projection.DEFINITE || $!chain.source.DEFINITE;
    self.create-comment-to-caller;
    my $*RED-INTERNAL = True;
    my $iter = Red::ResultSeq::Iterator.new: :$.of, :ast(Red::AST::Delete.new: $.of, $.filter), :&.post, |(:driver($_) with $!with);

    $!lock.protect: {
        self.create-comment-to-caller;
        Seq.new: $iter
    }
}

#| Saves any change on any element of that ResultSet
method save(::?CLASS:D:) is hidden-from-sql-commenting {
    X::Red::Projection.new(:reason("Projected values cannot be saved")).throw
        if $!chain.projection.DEFINITE || $!chain.source.DEFINITE;
    self.create-comment-to-caller;
    my @*UPDATE;
    die "You should use a map updating value(s) before saving" unless $.of.^can: "orig-result-seq";
    $.of.orig-result-seq.of.^apply-row-phasers(BeforeUpdate);
    my $*RED-INTERNAL = True;
    my $iter = Red::ResultSeq::Iterator.new: :of($.of.orig-result-seq.of), :ast(Red::AST::Update.new: :model($.table-list.head), :values[|@!update, |@*UPDATE], :filter($.filter));

    $!lock.protect: {
        self.create-comment-to-caller;
        Seq.new: $iter
    }
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
multi method join-model(Str $model, |c) {
    try require ::($model);
    self.join-model(::($model), |c)
}

#| Create a custom join (SQL join)
multi method join-model(Red::Model \model, &on, :$name = "{ self.^shortname }_{ model.^shortname }", *%pars where { .elems == 0 || ( .elems == 1 && so .values.head ) }) {
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
        self.of.^join(model, &on, :$name, |%pars).^all.clone: :$!chain
    }
}

method prefetch($defined? is copy, *%prefetches) {
    my @prefetches =
        |$.of.^pre-fetches,
        |@!prefetches,
    ;

    $defined = [$defined,] if $defined.defined && $defined !~~ Positional;
    @prefetches .= grep: {
        .name.substr(2) eq $defined.any
    } with $defined;

    my :(:@add, :@del) := %prefetches.pairs.classify: { .value ?? "add" !! "del" }, :as{ .key };

    @prefetches.append: @.^attributes.grep: {
        .name.substr(2) eq @add.any
    } if @add;

    @prefetches .= grep: {
        .name.substr(2) eq @del.none
    } if @del;

    self.clone: :@prefetches, :prefetches-set
}

#| Returns the AST that will generate the SQL
method ast(Bool :$sub-select --> Red::AST) is hidden-from-sql-commenting {
    if $.filter ~~ Red::AST::MultiSelect {
        $.filter
    } else {
        my @prefetch := $!prefetches-set ?? @!prefetches !! @($.of.^pre-fetches);
        Red::AST::Select.new:
            :$.of,          :$.filter,
            :$.limit,       :$.offset,
            :@.order,       :@.table-list,
            :@.group,       :@.comments,
            :@prefetch,     :$sub-select,
            :$!for,
            :source($!chain.source), :source-alias($!chain.source-alias),
            :fields($!chain.fields), :sources($!chain.sources),
        ;
    }
}
