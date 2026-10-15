use Red::AST;
use Red::AST::Value;
use Red::AST::Case;
use X::Red::Exceptions;

#| Describes the shape of one projected row independently of its SQL fields.
unit class Red::Projection;

my atomicint $projection-alias = 0;

method allocate-alias(::?CLASS:U: --> Str:D) {
    'red_projection_' ~ $projection-alias⚛++
}

has Str $.kind is required;
has Red::AST $.expression;
has Red::Projection @.children;
has Str @.keys;
has Mu $.model;
has Mu $.undefined-type = Mu;

#| Parameter-only relations can be returned as strings by database drivers.
method literal-inflator(::?CLASS:U: Mu:U $type --> Callable:D) {
    -> $value {
        given $type {
            when Bool { so $value.Int }
            when Int { $value.Int }
            when Rat { $value.Rat }
            when Num { $value.Num }
            when Str { $value.Str }
            when DateTime { $value ~~ DateTime ?? $value !! DateTime.new($value) }
            when Date { $value ~~ Date ?? $value !! Date.new($value) }
            when Blob { $type.new($value.list) }
            default { $value }
        }
    }
}

method from-value(::?CLASS:U: $value --> Red::Projection:D) {
    if $value ~~ Red::AST::Value {
        my $literal = $value.value;
        return self.from-value($literal) if $literal ~~ ::('Red::Model');
        return self.from-value($literal) if $literal ~~ Hash | Array | List;
        X::Red::Projection.new(:reason("Unsupported projection value: { $literal.^name }")).throw
            if $literal.DEFINITE && $literal !~~ Str | Numeric | Bool | Date | DateTime | Blob;
    }
    if $value ~~ ::('Red::Model') && !$value.DEFINITE {
        return self.new(:kind<model>, :model($value.^orig),
            :keys($value.^columns.map({ .name.substr(2) })),
            :children($value.^columns.map({
                my $column = .column;
                self.from-value($column.computation ~~ ::('Red::AST::Reference')
                    ?? $column.computation.clone(:origin($column)) !! $column)
            })));
    }
    if $value ~~ Red::AST {
        return self.new: :kind<leaf>, :expression($value),
            :undefined-type($value.^can('undefined-type') ?? $value.undefined-type !! Mu);
    }
    if $value ~~ Hash {
        my @keys = $value.keys.sort;
        return self.new: :kind<hash>, :@keys,
            :children(@keys.map({ self.from-value($value{$_}) }));
    }
    if $value ~~ Array | List {
        return self.new: :kind($value ~~ Array ?? 'array' !! 'list'),
            :children($value.map({ self.from-value($_) }));
    }
    if !$value.DEFINITE || $value ~~ Str | Numeric | Bool | Date | DateTime | Blob {
        return self.new: :kind<leaf>, :expression(ast-value($value));
    }
    X::Red::Projection.new(:reason("Unsupported projection value: { $value.^name }")).throw;
}

#| Tracks whether a JSON value denotes a present value rather than an absent path.
method json-presence(::?CLASS:U: Red::AST:D $value --> Red::AST:D) {
    if $value ~~ ::('Red::AST::JsonItem') {
        return ::('Red::AST::JsonOperation').new(:operation<exists>, :$value);
    }
    if $value ~~ ::('Red::AST::Reference') {
        return $value.presence if $value.presence.DEFINITE;
    }
    if $value ~~ ::('Red::Column') && $value.computation.DEFINITE {
        return self.json-presence($value.computation);
    }
    if $value ~~ Red::AST::Case {
        my Red::AST %when{Red::AST};
        for $value.when.kv -> $condition, $branch {
            %when{$condition} = self.json-presence($branch);
        }
        return Red::AST::Case.new(:case($value.case), :%when,
            :else($value.else.DEFINITE ?? self.json-presence($value.else) !! ast-value(True)));
    }
    ast-value(True)
}

#| Whether an expression can be substituted into another SQL clause.
method safe-to-repeat(::?CLASS:U: $value --> Bool:D) {
    return True unless $value.DEFINITE;
    if $value ~~ Red::AST::Value {
        return self.safe-to-repeat($value.value);
    }
    if $value ~~ Hash {
        return so $value.kv.map({ self.safe-to-repeat($_) }).all;
    }
    if $value ~~ Positional {
        return so $value.map({ self.safe-to-repeat($_) }).all;
    }
    return True unless $value ~~ Red::AST;
    my $name = $value.^name.split('+', 2).head;
    return True if $value ~~ ::('Red::Column') | ::('Red::AST::Reference');
    if $name eq 'Red::AST::Cast' {
        # String interpolation can safely stringify numeric expressions.
        return so !($value.returns === Any)
            && ($value.returns === $value.value.returns
                || ($value.returns === Numeric && $value.value.returns ~~ Numeric)
                || ($value.returns === Str && $value.value.returns ~~ Numeric))
            && self.safe-to-repeat($value.value);
    }
    if $name eq 'Red::AST::Function' {
        return False unless $value.func.uc eq any(<LOWER UPPER SUBSTR INSTR>);
    } else {
        return False unless $name eq any(<
            Red::AST::Sum Red::AST::Sub Red::AST::Mul Red::AST::Concat
            Red::AST::Eq Red::AST::Ne Red::AST::Lt Red::AST::Le Red::AST::Gt Red::AST::Ge
            Red::AST::AND Red::AST::OR Red::AST::Not Red::AST::So Red::AST::Like
            Red::AST::Case Red::AST::IsDefined Red::AST::JsonItem Red::AST::JsonOperation
            Red::AST::Substring Red::AST::Index Red::AST::Lowercase Red::AST::Uppercase
        >);
    }
    so $value.args.map({ self.safe-to-repeat($_) }).all
}

method signature(--> Str:D) {
    ($!kind, ($!kind eq 'model' ?? $!model.WHICH.Str !! ''),
        @!keys.List, @!children.map(*.signature).List).raku
}

method leaves(--> List:D) {
    $!kind eq 'leaf' ?? ($!expression,) !! @!children.flatmap(*.leaves).List
}

method replace-leaves(@expressions --> Red::Projection:D) {
    my Int $index = 0;
    self.rebind-leaves(@expressions, $index)
}

#| Internal extension point for rebinding a shape to exported SQL fields.
method rebind-leaves(@expressions, Int $index is rw --> Red::Projection:D) {
    return self.clone(:expression(@expressions[$index++])) if $!kind eq 'leaf';
    self.clone: :children(@!children.map({ .rebind-leaves(@expressions, $index) }))
}

#| Preserve the type objects supplied as nullable literal values.
method with-undefined-types(@types, Int $index is rw --> Red::Projection:D) {
    return self.clone(:undefined-type(@types[$index++])) if $!kind eq 'leaf';
    self.clone(:children(@!children.map({ .with-undefined-types(@types, $index) })))
}

method construct(@values) {
    my Int $index = 0;
    self.materialize(@values, $index)
}

#| Internal extension point for reconstructing one result element.
method materialize(@values, Int $index is rw) {
    if $!kind eq 'leaf' {
        my $value = @values[$index++];
        return $!undefined-type if $!undefined-type !=== Mu
            && $value !~~ Red::AST && !$value.DEFINITE;
        return $value;
    }
    if $!kind eq 'model' {
        my @members = @!children.map({ .materialize(@values, $index).item });
        if @members.grep({ $_ ~~ Red::AST }).elems {
            return @members.head.class if @members.head ~~ ::('Red::Column');
            my Str $table = @members.head.table;
            my $alias = $!model.^alias($table ~ '_model_' ~ @members.head.name);
            my role ModelSource[Str $source, Str $group] {
                method as(|) { $source }
                method tables(\type) { [type] }
                method create-rel-name(Mu \type, $name) { "{$source}_{$group}_$name" }
            }
            $alias.HOW does ModelSource[$table, @members.head.name];
            for $alias.^columns.kv -> $i, $attr {
                $attr.args<computation> = @members[$i];
                $attr.args<model> = $alias;
                $attr.args<class> = $alias;
                $attr.create-column($alias);
            }
            return $alias;
        } else {
            my $object = $!model.new(|@!keys.kv.map(-> $i, $key { $key => @members[$i] }).Hash);
            $object.^clean-up;
            $object.^saved-on-db;
            return $object;
        }
    } elsif $!kind eq 'hash' {
        return @!keys.kv.map(-> $i, $key {
            $key => @!children[$i].materialize(@values, $index)
        }).Hash;
    }
    my @items = @!children.map({ .materialize(@values, $index).item });
    $!kind eq 'array' ?? @items.Array !! @items.List
}

method from-branches(::?CLASS:U: %branches --> Red::Projection:D) {
    my @branches = %branches.pairs;
    my @shapes = @branches.map({ self.from-value(.value) });
    my $shape = @shapes.head;
    X::Red::Projection.new(:reason("Conditional projections must have the same shape")).throw
        unless @shapes.all.signature eq $shape.signature;
    my @leaves = @shapes.map({ .leaves.Array });
    my @expressions = do for ^$shape.leaves.elems -> $i {
        my Red::AST %when{Red::AST};
        for @branches.kv -> $j, $branch {
            %when{$branch.key} = @leaves[$j][$i];
        }
        Red::AST::Case.new(:%when)
    };
    $shape.replace-leaves(@expressions)
}
