use X::Red::Exceptions;

#| Data-only Thompson automata, shared by SQL evaluation and dialect lowering.
unit class Red::Regex::Automaton;

has List $.tree is required;
has Bool $.ignore = False;

method unsupported(Str:D $reason) {
    X::Red::Compiler::Unsupported.new(:fatal, :$reason).throw
}

has Int $!next-state = 0;
has @!edges;

method state(--> Int:D) {
    self.unsupported('SQL regex exceeds the 4096-state compilation limit')
        if $!next-state >= 4096;
    $!next-state++
}

method edge(Int:D $from, Int:D $to, Int:D $step, $test = ['empty'], Bool :$ignore = False) {
    @!edges.push: [$from, $to, $step, $test, $ignore];
}

method fragment($tree, Bool :$ignore = False --> List:D) {
    return self.fragment($tree[1], :$ignore) if $tree[0] eq 'scope';
    my $start = self.state;
    my $end = self.state;
    given $tree[0] {
        when 'empty' | 'match-boundary' { self.edge($start, $end, 0) }
        when 'never' { self.edge($end, $end, 0) }
        when 'literal' {
            my $from = $start;
            for $tree[1].ords -> $character {
                my $to = self.state;
                self.edge($from, $to, 1, ['literal', $character.chr], :$ignore);
                $from = $to;
            }
            self.edge($from, $end, 0);
        }
        when 'group' | 'capture' | 'mode' {
            my $mode = $tree[0] eq 'mode';
            my ($from, $to) = self.fragment(
                $tree[$mode || $tree[0] eq 'capture' ?? 2 !! 1],
                :ignore($mode ?? $tree[1] !! $ignore));
            self.edge($start, $from, 0);
            self.edge($to, $end, 0);
        }
        when 'sequence' {
            my $previous = $start;
            for $tree.skip(1) -> $part {
                my ($from, $to) = self.fragment($part, :$ignore);
                self.edge($previous, $from, 0);
                $previous = $to;
            }
            self.edge($previous, $end, 0);
        }
        when 'alternative' {
            for $tree.skip(1) -> $part {
                my ($from, $to) = self.fragment($part, :$ignore);
                self.edge($start, $from, 0);
                self.edge($to, $end, 0);
            }
        }
        when 'repeat' {
            my ($body, $minimum, $maximum) = $tree[1..3];
            self.unsupported('SQL repetition exceeds the 4096-state compilation limit')
                if $minimum > 1024 || $maximum > 1024;
            my $previous = $start;
            for ^$minimum {
                my ($from, $to) = self.fragment($body, :$ignore);
                self.edge($previous, $from, 0);
                $previous = $to;
            }
            if $maximum == -1 {
                my ($from, $to) = self.fragment($body, :$ignore);
                self.edge($previous, $end, 0);
                self.edge($previous, $from, 0);
                self.edge($to, $previous, 0);
            } else {
                for $minimum ..^ $maximum {
                    my ($from, $to) = self.fragment($body, :$ignore);
                    self.edge($previous, $end, 0);
                    self.edge($previous, $from, 0);
                    $previous = $to;
                }
                self.edge($previous, $end, 0);
            }
        }
        when 'intersection' {
            my @parts = $tree.skip(1);
            my $part = @parts.shift;
            for @parts -> $right {
                $part = ['intersection-pair', $part, $right];
            }
            my ($from, $to) = self.fragment($part, :$ignore);
            self.edge($start, $from, 0);
            self.edge($to, $end, 0);
        }
        when 'intersection-pair' {
            self.product($tree[1], $tree[2], $start, $end, :$ignore);
        }
        when 'any' | 'class' | 'characters' | 'ranges' | 'set' { self.edge($start, $end, 1, $tree, :$ignore) }
        when 'anchor' | 'look' | 'same' { self.edge($start, $end, 0, $tree, :$ignore) }
        default { self.unsupported("Operation {$tree[0]} is not supported by the SQL automaton") }
    }
    ($start, $end)
}


method graph(--> Hash:D) {
    my ($start, $accept) = self.fragment($!tree, :ignore($!ignore));
    { :$start, :$accept, :states($!next-state), :edges(@!edges.List) }
}

method product($left, $right, Int:D $start, Int:D $end, Bool :$ignore = False) {
    my $a = self.WHAT.new(:tree($left.List), :$ignore).graph;
    my $b = self.WHAT.new(:tree($right.List), :$ignore).graph;
    my %a-edges;
    my %b-edges;
    (%a-edges{$_[0]} //= []).push($_) for $a<edges>.list;
    (%b-edges{$_[0]} //= []).push($_) for $b<edges>.list;
    my %states;
    my @queue;
    my &state = -> Int $from-a, Int $from-b {
        my $key = "$from-a,$from-b";
        unless %states{$key}:exists {
            %states{$key} = self.state;
            @queue.push: [$from-a, $from-b];
        }
        %states{$key}
    };
    self.edge($start, state($a<start>, $b<start>), 0);
    my $position = 0;
    while $position < @queue.elems {
        my ($from-a, $from-b) = @queue[$position++].list;
        my $from = state($from-a, $from-b);
        self.edge($from, $end, 0) if $from-a == $a<accept> && $from-b == $b<accept>;
        my @a = (%a-edges{$from-a} // []).list;
        my @b = (%b-edges{$from-b} // []).list;
        for @a.grep({ .[2] == 0 }) -> $edge {
            self.edge($from, state($edge[1], $from-b), 0, $edge[3], :ignore($edge[4]));
        }
        for @b.grep({ .[2] == 0 }) -> $edge {
            self.edge($from, state($from-a, $edge[1]), 0, $edge[3], :ignore($edge[4]));
        }
        for @a.grep({ .[2] == 1 }) -> $edge-a {
            for @b.grep({ .[2] == 1 }) -> $edge-b {
                self.edge($from, state($edge-a[1], $edge-b[1]), 1,
                    ['both', $edge-a[3], $edge-a[4], $edge-b[3], $edge-b[4]], :$ignore);
            }
        }
    }
    Nil
}

#| Eliminate states to render regular conjunctions for native regex engines.
#| Resource limits fail explicitly before constructing an unbounded pattern.
method render(&render --> Str:D) {
    my $graph = self.graph;
    self.unsupported('Native regex conjunction exceeds the 128-state lowering limit')
        if $graph<states> > 128;
    my %arcs;
    my &merge = -> Int $from, Int $to, Str $incoming {
        my $pattern = $incoming;
        my $key = "$from,$to";
        if %arcs{$key}:exists {
            my $old = %arcs{$key};
            $pattern = $old eq $pattern ?? $old !! '(?:' ~ $old ~ '|' ~ $pattern ~ ')';
        }
        self.unsupported('Native regex conjunction exceeds the 64KiB pattern limit')
            if $pattern.chars > 65536;
        %arcs{$key} = $pattern;
    };
    for $graph<edges>.list -> $edge {
        merge($edge[0], $edge[1], render($edge[3], $edge[4]));
    }
    my $start = $graph<states>;
    my $end = $start + 1;
    merge($start, $graph<start>, '');
    merge($graph<accept>, $end, '');
    my @remaining = ^$graph<states>;
    while @remaining {
        my @connections = %arcs.keys.map(*.split(',')>>.Int.List);
        my %in;
        my %out;
        for @connections -> $pair {
            %out{$pair[0]}++;
            %in{$pair[1]}++;
        }
        my $state = @remaining.min(-> $id { (%in{$id} // 0) * (%out{$id} // 0) });
        my @incoming = @connections.grep({ .[1] == $state && .[0] != $state }).map(*[0]);
        my @outgoing = @connections.grep({ .[0] == $state && .[1] != $state }).map(*[1]);
        my $loop = %arcs{"$state,$state"} // '';
        my $repeat = $loop.chars ?? '(?:' ~ $loop ~ ')*' !! '';
        for @incoming -> $from {
            for @outgoing -> $to {
                merge($from, $to, %arcs{"$from,$state"} ~ $repeat ~ %arcs{"$state,$to"});
            }
        }
        for %arcs.keys -> $key {
            %arcs{$key}:delete if $key.split(',').grep({ .Int == $state });
        }
        @remaining = @remaining.grep(* != $state);
    }
    %arcs{"$start,$end"}:exists
        ?? (%arcs{"$start,$end"}.chars ?? %arcs{"$start,$end"} !! '(?:)') !! '(?!)'
}
