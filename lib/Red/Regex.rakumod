use X::Red::Exceptions;

#| A data-only regex tree. Drivers decide which operations their engine supports.
unit class Red::Regex;

has List $.tree is required;
has List $.capture-slots = ().List;
has Map $.named-slots = Map.new;
has List $.unsafe-captures = ().List;

method capture-groups($selection --> List:D) {
    my @groups = $selection ~~ Int
        ?? (0 <= $selection < $!capture-slots.elems
            ?? $!capture-slots[$selection].list !! ())
        !! ($!named-slots{$selection} // ()).list;
    self.unsupported('Reading capture lists as scalar SQL text is not supported')
        if @groups.grep({ $_ eq any($!unsafe-captures) });
    @groups.List
}

method unsupported(Str:D $reason) {
    X::Red::Compiler::Unsupported.new(:fatal,:reason("SQL regex: $reason")).throw
}

method escape(Str:D $text --> Str:D) {
    self.unsupported('NUL characters cannot be represented by all SQL regex engines')
        if $text.contains("\0");
    $text.ords.map(*.chr).map({ $_ eq any('\\', '.', '^', '$', '|', '?', '*', '+',
        '(', ')', '[', ']', '{', '}') ?? '\\' ~ $_ !! $_ }).join
}

method render(Str:D :$dialect! --> Str:D) {
    self.render-info(:$dialect)<pattern>
}

#| Compatibility entry point: rendering belongs to the selected driver distribution.
method render-info(Str:D :$dialect!, :@capture-ids = (),
    Bool :$whole = False --> Hash:D) {
    my $renderer = "Red::Driver::{$dialect}::Regex";
    try {
        require ::($renderer);
        CATCH {
            default { self.unsupported("Cannot load regex renderer $renderer: {.message}") }
        }
    }
    ::($renderer).new(:tree($!tree), :capture-slots($!capture-slots),
        :named-slots($!named-slots), :unsafe-captures($!unsafe-captures))
        .render-info(:$dialect, :@capture-ids, :$whole)
}

#| Infer literal-only filters so drivers can use string operations directly.
method literal-filter(--> Hash) {
    my $tree = $!tree;
    my Bool $ignore = False;
    while $tree[0] eq any(<group scope capture mode>) {
        if $tree[0] eq 'mode' {
            $ignore = $tree[1];
            $tree = $tree[2];
        } else {
            $tree = $tree[$tree[0] eq 'capture' ?? 2 !! 1];
        }
    }
    my @parts = $tree[0] eq 'sequence' ?? $tree.skip(1) !! ($tree,);
    my Bool $begin = so @parts && @parts[0][0] eq 'anchor' && @parts[0][1] eq 'begin';
    @parts.shift if $begin;
    my Bool $end = so @parts && @parts[*-1][0] eq 'anchor' && @parts[*-1][1] eq 'end';
    @parts.pop if $end;
    my @text = @parts.map({ self.literal-text($_) });
    return Hash if @text.grep({ !.defined });
    my $mode = $begin && $end ?? 'exact' !! $begin ?? 'prefix' !! $end ?? 'suffix' !! 'contains';
    { :text(@text.join), :$mode, :$ignore }
}

#| Fixed literal assertions can also be compiled without a native regex engine.
method literal-text($tree = $!tree) {
    given $tree[0] {
        when 'literal' { $tree[1] }
        when 'empty' | 'match-boundary' { '' }
        when 'group' | 'scope' | 'atomic' { self.literal-text($tree[1]) }
        when 'capture' { self.literal-text($tree[2]) }
        when 'sequence' {
            my @parts = $tree.skip(1).map({ self.literal-text($_) });
            @parts.grep({ !.defined }) ?? Str !! @parts.join
        }
        default { Str }
    }
}

method maximum-width($tree = $!tree) {
    given $tree[0] {
        when 'empty' | 'match-boundary' | 'never' | 'anchor' | 'look' | 'same' { 0 }
        when 'literal' { $tree[1].ords.elems }
        when 'any' | 'class' | 'characters' | 'ranges' | 'set' | 'both' { 1 }
        when 'sequence' { $tree.skip(1).map({ self.maximum-width($_) }).sum }
        when 'alternative' { $tree.skip(1).map({ self.maximum-width($_) }).max // 0 }
        when 'intersection' { $tree.skip(1).map({ self.maximum-width($_) }).min // 0 }
        when 'group' | 'scope' | 'atomic' { self.maximum-width($tree[1]) }
        when 'capture' { self.maximum-width($tree[2]) }
        when 'backreference' | 'literal-slot' { Inf }
        when 'mode' { self.maximum-width($tree[2]) }
        when 'repeat' {
            my $body = self.maximum-width($tree[1]);
            $body == 0 ?? 0 !! $tree[3] == -1 ?? Inf !! $body * $tree[3]
        }
        default { self.unsupported("Unknown regex width for {$tree[0]}") }
    }
}

method walk(&visit, $tree = $!tree, Bool :$descend-capture-scopes = True) {
    visit($tree);
    return Nil if !$descend-capture-scopes && $tree[0] eq any(<scope look>);
    given $tree[0] {
        when 'sequence' | 'alternative' | 'intersection' {
            self.walk(&visit, $_, :$descend-capture-scopes) for $tree.skip(1);
        }
        when 'group' | 'scope' | 'repeat' | 'atomic' {
            self.walk(&visit, $tree[1], :$descend-capture-scopes);
        }
        when 'capture' | 'mode' { self.walk(&visit, $tree[2], :$descend-capture-scopes) }
        when 'look' { self.walk(&visit, $tree[3], :$descend-capture-scopes) }
        when 'set' {
            self.walk(&visit, $tree[2], :$descend-capture-scopes);
            self.walk(&visit, $tree[3], :$descend-capture-scopes);
        }
        when 'both' {
            self.walk(&visit, $tree[1], :$descend-capture-scopes);
            self.walk(&visit, $tree[3], :$descend-capture-scopes);
        }
    }
    Nil
}

method literal-value($value --> Str:D) {
    my $type = $value.WHAT;
    self.unsupported('Regex literal interpolation requires defined primitive data')
        unless $value.defined && ($type === Str || $type === Int || $type === Num
            || $type === Rat || $type === Bool);
    $value.Str
}

method instantiate(Positional:D $values --> Red::Regex:D) {
    sub replace($tree --> Array:D) {
        my @part = $tree.list;
        given @part[0] {
            when 'literal-slot' {
                self.unsupported('Missing regex interpolation value') unless @part[1] < $values.elems;
                my $value = $values[@part[1]];
                if $value ~~ Array | List {
                    my @strings = $value.list.map({ self.literal-value($_) });
                    return @part[2] eq 'alternatives'
                        ?? (@strings ?? ['alternative', |@strings.map({ ['literal', $_] })]
                            !! ['never'])
                        !! ['literal', @strings.join(' ')];
                }
                ['literal', self.literal-value($value)]
            }
            when 'sequence' | 'alternative' | 'intersection' {
                [@part[0], |@part.skip(1).map({ replace($_) })]
            }
            when 'group' | 'scope' | 'repeat' | 'atomic' {
                [@part[0], replace(@part[1]), |@part.skip(2)]
            }
            when 'capture' | 'mode' { [@part[0], @part[1], replace(@part[2])] }
            when 'look' { [@part[0], @part[1], @part[2], replace(@part[3])] }
            when 'set' { [@part[0], @part[1], replace(@part[2]), replace(@part[3])] }
            when 'both' {
                [@part[0], replace(@part[1]), @part[2], replace(@part[3]), @part[4]]
            }
            default { @part.Array }
        }
    }
    self.WHAT.new(:tree(replace($!tree).List), :$!capture-slots,
        :$!named-slots, :$!unsafe-captures)
}
