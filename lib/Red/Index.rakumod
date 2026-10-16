use Red::AST;
use Red::AST::CreateIndex;
use Red::AST::Function;
use Red::Attr::Index;
use Red::Column;
use Red::Utils;
use X::Red::Exceptions;

unit module Red::Index;

sub index-error(Str $reason) is export {
    X::Red::Index.new(:$reason).throw
}

sub evaluate-index(Callable $expression, $context) {
    CATCH {
        when X::Red::Index { .rethrow }
        default { index-error("Cannot resolve index expression: {.message}") }
    }
    $expression($context)
}

#| Normalize the value shared by the attribute trait and is column configuration.
sub index-options($value --> Hash) is export {
    return %( :disabled ) if $value ~~ Bool && !$value;
    return %( :names[], :expression(Callable) ) if $value ~~ Bool;
    return %( :names[], :expression($value) ) if $value ~~ Callable;
    my @parts = $value ~~ Positional ?? $value.list !! ($value,);
    my $expression = Callable;
    if @parts && @parts.tail ~~ Callable {
        $expression = @parts.pop;
    }
    my @names = @parts.map({ $_ ~~ Positional ?? |.list !! $_ });
    index-error('Index names must be nonempty strings')
        unless @names && @names.all ~~ Str:D && @names.all.chars;
    %( :names(@names.unique.Array), :$expression )
}

#| Lower an expression to DDL without modifying the AST used by queries.
sub index-expression($value, Mu:U $model --> Red::AST) is export {
    index-error('An index key must be a Red expression') unless $value ~~ Red::AST:D;
    if $value ~~ Red::Column {
        index-error('Index keys must reference stored columns of their own model')
            unless ($value.class.^orig === $model.^orig || $model.^isa($value.class))
                && !$value.computation.DEFINITE;
        return Red::AST::IndexColumn.new:
            :name($value.name), :value-type($value.returns);
    }
    my $kind = $value.^name;
    index-error("Unsupported index expression: $kind")
        if $kind.contains(any(<Select ResultSeq Reference Aggregate Ordering Count>));
    if $value ~~ Red::AST::Function {
        index-error('Aggregate functions are not index keys')
            if $value.func.uc eq any(<COUNT SUM AVG MIN MAX STRING_AGG ARRAY_AGG JSON_AGG>);
    }
    my %changes;
    for $value.^attributes -> $attr {
        my $key = $attr.name.substr(2);
        my $part = $attr.get_value($value);
        if $key eq any(<bind bind-left bind-right>) {
            %changes{$key} = False;
        } elsif $part ~~ Red::AST:D {
            %changes{$key} = index-expression($part, $model);
        } elsif $part ~~ Positional {
            %changes{$key} = $part.map({
                $_ ~~ Red::AST:D ?? index-expression($_, $model) !! $_
            }).Array;
        }
    }
    $value.clone: |%changes
}

sub index-name(Str $table, Str $logical, Bool $unique --> Str) {
    my $name = "{$table}_{kebab-to-snake-case($logical)}_{$unique ?? 'uidx' !! 'idx'}";
    # A shared 63-byte bound is portable across the supported databases.
    return $name if $name.encode('utf8').bytes <= 63;
    my Int $hash = 2166136261;
    for $name.encode('utf8').list -> $byte {
        $hash = (($hash +^ $byte) * 16777619) +& 0xffffffff;
    }
    my $prefix = $name;
    $prefix = $prefix.substr(0, *-1) while $prefix.encode('utf8').bytes > 54;
    $prefix ~ '_' ~ $hash.fmt('%08x')
}

sub model-indexes(Mu:U $model --> Array) is export {
    my $*RED-INTERNAL = True;
    my @definitions;
    my %groups;
    my %kinds;
    sub contribute(Str $logical, Bool $unique, $expression, Bool $inline, Str $group) {
        if %kinds{$group}:exists {
            index-error("Conflicting index declarations: $logical")
                if %kinds{$group} != $unique;
        }
        %kinds{$group} = $unique;
        unless %groups{$group}:exists {
            %groups{$group} = @definitions.elems;
            @definitions.push: { :$logical, :$unique, :$inline, :keys[] };
        }
        my %definition := @definitions[%groups{$group}];
        %definition<inline> &&= $inline;
        %definition<keys>.push: index-expression($expression, $model);
    }
    for $model.^columns -> $attr {
        index-error('An attribute cannot be both an index declaration and a column')
            if $attr ~~ Red::Attr::Index;
        for <indexed unique> -> $kind {
            next unless $attr.args{$kind}:exists;
            my %option = index-options($attr.args{$kind});
            next if %option<disabled>;
            my $column = $attr.column;
            my $expression = %option<expression>.DEFINITE
                ?? evaluate-index(%option<expression>, $column) !! $column;
            my @names = %option<names>.list;
            my Bool $named = so @names;
            @names = ($column.attr-name,) unless @names;
            for @names -> $name {
                contribute($name, $kind eq 'unique', $expression,
                    $kind eq 'unique' && !%option<expression>.DEFINITE,
                    $named ?? "named:$name" !! "column:{$kind}:{$attr.name}");
            }
        }
    }
    for $model.^attributes.grep(Red::Attr::Index) -> $attr {
        my $logical = $attr.name.substr(2);
        index-error("Conflicting index declarations: $logical")
            if @definitions.first({ .<logical> eq $logical }).defined;
        my $result = evaluate-index($attr.index-expression, $model);
        my @keys = $result ~~ Positional ?? $result.list !! ($result,);
        index-error("Index $logical has no keys") unless @keys;
        for @keys -> $key {
            contribute($logical, $attr.unique-index, $key, False, "independent:$logical");
        }
    }
    my %names;
    @definitions.map(-> %definition {
        my @keys = %definition<keys>.list;
        index-error('Every index key must reference a column')
            unless @keys.map({ .transpose-grep(* ~~ Red::AST::IndexColumn).elems > 0 }).all;
        my $name = index-name($model.^table, %definition<logical>, %definition<unique>);
        index-error("Index name collision: $name") if %names{$name}++;
        Red::AST::CreateIndex.new:
            :table($model.^table), :$name, :logical-name(%definition<logical>),
            :unique(%definition<unique>), :inline(%definition<inline>), :@keys;
    }).Array
}

#| Compare catalog spelling without altering literals, grouping or identifier case.
sub canonical-index-key(Str $sql --> Str) is export {
    my @tokens;
    my @chars = $sql.comb;
    while @chars {
        my $char = @chars.shift;
        if $char eq any("'", '"', '`', '[') {
            my $quote = $char eq '[' ?? ']' !! $char;
            my $token = '';
            while @chars {
                my $next = @chars.shift;
                if $next eq $quote {
                    if @chars && @chars[0] eq $quote {
                        $token ~= @chars.shift;
                    } else {
                        last;
                    }
                } else {
                    $token ~= $next;
                }
            }
            @tokens.push: $quote eq "'"
                ?? "'" ~ $token.subst("'", "''", :g) ~ "'"
                !! ($token ~~ /^ <[a..z_]> <[a..z0..9_\$]>* $/
                    ?? $token !! '"' ~ $token.subst('"', '""', :g) ~ '"');
        } elsif $char ~~ /<[A..Za..z0..9_\$]>/ {
            my $word = $char;
            $word ~= @chars.shift while @chars && @chars[0] ~~ /<[A..Za..z0..9_\$]>/;
            @tokens.push: $word.lc;
        } elsif $char eq ':' && @chars && @chars[0] eq ':' {
            @chars.shift;
            @tokens.push: '::';
        } elsif $char !~~ /\s/ {
            @tokens.push: $char;
        }
    }
    # PostgreSQL inserts text casts in text functions. Do not erase a standalone
    # cast: an index on id::text is different from an index on integer id.
    my @text-context;
    my Int $i = 0;
    while $i < @tokens.elems - 1 {
        if @tokens[$i] eq '(' {
            @text-context.push: $i > 0 && @tokens[$i - 1] eq any(
                <lower upper length char_length substring substr trim btrim ltrim rtrim replace strpos>
            );
        } elsif @tokens[$i] eq ')' {
            @text-context.pop;
        }
        if @tokens[$i] eq '::' && @tokens[$i + 1] eq 'text' && @text-context.grep(*.Bool) {
            @tokens.splice($i, 2);
        } else {
            $i++;
        }
    }
    # Remove redundant wrapping of an atom, preserving function-call parentheses.
    $i = 0;
    while $i < @tokens.elems - 2 {
        if @tokens[$i] eq '(' && @tokens[$i + 2] eq ')'
            && @tokens[$i + 1] ne any('(', ')')
            && ($i == 0 || @tokens[$i - 1] !~~ /<[\w]> $/) {
            @tokens.splice($i, 3, @tokens[$i + 1]);
            $i = 0;
        } else {
            $i++;
        }
    }
    loop {
        last unless @tokens.elems >= 2 && @tokens.head eq '(' && @tokens.tail eq ')';
        my Int $depth = 0;
        my Bool $outer = True;
        for @tokens.kv -> $i, $token {
            $depth++ if $token eq '(';
            $depth-- if $token eq ')';
            $outer = False if $depth == 0 && $i < @tokens.elems - 1;
        }
        last unless $outer;
        @tokens.shift;
        @tokens.pop;
    }
    @tokens.join(' ')
}

#| Read an index key list without splitting commas inside expressions or literals.
sub sql-index-keys(Str $sql --> Array) is export {
    my @keys;
    my Str $part = '';
    my Str $quote = '';
    my Int $depth = 0;
    my @chars = $sql.comb;
    while @chars {
        my $char = @chars.shift;
        if $quote.chars {
            $part ~= $char if $depth;
            if $char eq $quote {
                if @chars && @chars[0] eq $quote {
                    my $escaped = @chars.shift;
                    $part ~= $escaped if $depth;
                } else {
                    $quote = '';
                }
            }
        } elsif $char eq any("'", '"', '`', '[') {
            $quote = $char eq '[' ?? ']' !! $char;
            $part ~= $char if $depth;
        } elsif $char eq '(' {
            $part ~= $char if $depth++;
        } elsif $char eq ')' {
            if --$depth == 0 {
                @keys.push: $part.trim;
                return @keys.Array;
            }
            $part ~= $char;
        } elsif $char eq ',' && $depth == 1 {
            @keys.push: $part.trim;
            $part = '';
        } else {
            $part ~= $char if $depth;
        }
    }
    index-error('Cannot read index keys from catalog SQL')
}
