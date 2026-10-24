use nqp;
use Red::AST;
use Red::AST::BoundFilter;

#| SQL and parameter positions only. Connections, cursors and captures stay private.
unit class Red::QueryPlan;

has List $.statements is required;

# Fingerprint actual state, including mutable AST attributes. Unknown values bypass
# caching rather than trusting object identity for mutable user data.
method describe(Red::AST:D $ast --> Hash:D) {
    my Bool $safe = True;
    my %active;
    my @parameters;
    my @comments;
    my @reasons;
    my $shared-cache;
    sub frame(Mu $part --> Str) {
        return 's' ~ $part.chars ~ ':' ~ $part if $part.DEFINITE && $part.WHAT === Str;
        my $source = $part.raku;
        'r' ~ $source.chars ~ ':' ~ $source
    }
    sub walk(Mu $value --> Str) {
        # After a cache veto, keep finding bindings and comments but stop encoding keys.
        unless $value.DEFINITE {
            return '' unless $safe;
            return 'model:' ~ $value.WHICH.Str ~ ':' ~ $value.^table ~ ':' ~ $value.^as
                if $value ~~ ::('Red::Model') && $value.HOW.^can('table');
            return 'U:' ~ $value.WHICH.Str;
        }
        my $type = $value.WHAT;
        return $safe ?? 'Str:' ~ $value.chars ~ ':' ~ $value !! '' if $type === Str;
        return $safe ?? $type.^name ~ ':' ~ $value.raku !! ''
            if $type === Int || $type === Rat
                || $type === Num || $type === Bool || $value ~~ Enumeration;
        if $value ~~ Callable || $value ~~ Attribute {
            return $safe ?? $value.WHICH.Str !! '';
        }
        if $value ~~ Red::AST::BoundFilter::Predicate {
            @parameters.push: $value;
            $shared-cache //= $value.cache;
            return 'bound:' ~ walk($value.filter);
        }
        if $value ~~ Positional && $value !~~ Red::AST {
            my $id = nqp::where(nqp::decont($value));
            if %active{$id}:exists {
                $safe = False;
                @reasons.push: 'cyclic positional value';
                return '';
            }
            %active{$id} = True;
            LEAVE %active{$id}:delete;
            return '[]' unless $value.elems;
            unless $safe {
                walk($_) for $value.list;
                return '';
            }
            return '[' ~ $value.list.map({ walk($_) }).join('|') ~ ']';
        }
        if $value ~~ Associative && $value !~~ Red::AST {
            $safe = False;
            my $id = nqp::where(nqp::decont($value));
            if %active{$id}:exists {
                @reasons.push: 'cyclic associative value';
                return '';
            }
            %active{$id} = True;
            LEAVE %active{$id}:delete;
            @reasons.push: $value.^name;
            for $value.kv -> $key, $item {
                walk($key);
                walk($item);
            }
            return '';
        }
        if $value ~~ ::('Red::Column') {
            unless $value.class.HOW.^can('table') {
                $safe = False;
                return '';
            }
            unless $safe {
                walk($value.computation);
                return '';
            }
            my @parts =
                $value.class.WHICH.Str, $value.class.^table, $value.class.^as,
                $value.name, $value.attr-name, $value.name-alias,
                $value.attr.type.WHICH.Str, walk($value.type), walk($value.computation);
            return $safe ?? 'column:' ~ @parts.map(&frame).join !! '';
        }
        if $value ~~ ::('Red::AST::Value') && $value.column.DEFINITE {
            $safe = False; # A custom deflator can depend on mutable external state.
        }
        if $value ~~ Red::AST {
            my $id = nqp::where(nqp::decont($value));
            if %active{$id}:exists {
                $safe = False;
                return '';
            }
            %active{$id} = True;
            LEAVE %active{$id}:delete;
            my @parts = $value.^attributes.map(-> $attr {
                my $part = $attr.get_value($value);
                if $attr.name eq '@!comments' {
                    @comments.append: $part.list;
                    next;
                }
                my $description = walk($part);
                next unless $safe;
                $attr.name ~ '=' ~ $description
            });
            return $safe ?? $value.^name ~ '(' ~ @parts.join('|') ~ ')' !! '';
        }
        $safe = False;
        @reasons.push: $value.^name;
        ''
    }
    my $key = walk($ast);
    # Models are type objects above; include their current SELECT column metadata.
    if $ast.^can('of') && $ast.of ~~ ::('Red::Model') {
        my $columns = $ast.of.^columns.map({ walk(.column) }).join('|');
        if $safe {
            $key ~= '|columns:' ~ $columns;
            $key ~= '|table:' ~ $ast.of.^table ~ '|alias:' ~ $ast.of.^as;
        }
    }
    %(:key($safe ?? $key !! Str), :@parameters, :@comments, :$shared-cache, :@reasons)
}

method compile($driver, Red::AST:D $ast, :@parameters = [] --> Red::QueryPlan:D) {
    my %*RED-PLAN-GROUPS = @parameters.kv.map(-> $index, $predicate {
        $predicate.binding-token.WHICH.Str => $index
    });
    my Bool $*RED-COLLECT-PLAN-BINDS = True;
    my Bool $*RED-COMMENT-SQL = False;
    my &*RED-COMMENT-SQL;
    my $optimized = $driver.optimize($ast);
    my @statements = (|$driver.translate($optimized)).map({
        Pair.new(.key, .value.Array.List)
    });
    self.new(:statements(@statements.List))
}

method prepare($driver, :@parameters = [], :@comments = [] --> List:D) {
    my $comments = ($*RED-COMMENT-SQL || &*RED-COMMENT-SQL)
        ?? @comments.map({ $driver.translate($_, 'comment').key }).join("\n") !! '';
    my @statements;
    for $!statements.list -> $entry {
        next unless $entry.key;
        next if $*RED-DRY-RUN;
        my @bind = $entry.value.map(-> $value {
            my $actual = $value ~~ Red::AST::BoundFilter::Bind
                ?? @parameters[$value.group].values[$value.index] !! $value;
            $driver.deflate($actual)
        });
        my $statement = $driver.prepare(($comments ?? "$comments\n" !! '') ~ $entry.key);
        $statement.predefined-bind;
        $statement.binds = @bind;
        @statements.push: $statement;
    }
    @statements.List
}
