use X::Red::Exceptions;
use Red::Regex::Automaton;

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

method render(Str:D :$dialect = 'Pg' --> Str:D) {
    self.render-info(:$dialect)<pattern>
}

method render-info(Str:D :$dialect = 'Pg', :@capture-ids = (),
    Bool :$whole = False --> Hash:D) {
    self.unsupported("Unknown regex dialect: $dialect") unless $dialect eq any(<Pg MySQL>);
    my %*RED-REGEX-REFERENCED;
    my %*RED-REGEX-CAPTURES;
    my Int $*RED-REGEX-NEXT-CAPTURE = $whole ?? 1 !! 0;
    %*RED-REGEX-REFERENCED{$_} = True for @capture-ids;
    self.walk(-> $part {
        self.unsupported('Whole match reads with Match boundary markers are not implemented')
            if $whole && $part[0] eq 'match-boundary';
        self.unsupported('The same-character assertion has no implemented PostgreSQL lowering')
            if $part[0] eq 'same' && $dialect eq 'Pg';
        if $part[0] eq 'backreference' {
            %*RED-REGEX-REFERENCED{$_} = True for $part[1].list;
        }
    });
    my $pattern = self!render($!tree, $dialect, True);
    $pattern = '(?:)' unless $pattern.chars;
    if $whole {
        my $prefix = '';
        for '(?i)', '(?c)' -> $flag {
            if $pattern.starts-with($flag) {
                $prefix = $flag;
                $pattern = $pattern.substr($flag.chars);
                last;
            }
        }
        $pattern = $prefix ~ '(' ~ $pattern ~ ')';
    }
    { :$pattern, :groups(%*RED-REGEX-CAPTURES.Map) }
}

method !render($tree, Str:D $dialect, Bool $root = False, Bool $ignore = False --> Str:D) {
    my @part = $tree.list;
    given @part[0] {
        when 'empty' | 'match-boundary' { '' }
        when 'never' { '(?!)' }
        when 'literal-slot' { self.unsupported('Regex literal interpolation needs bound values') }
        when 'literal' { self.escape(@part[1]) }
        when 'sequence' { @part.skip(1).map({ self!render($_, $dialect, False, $ignore) }).join }
        when 'alternative' {
            '(?:' ~ @part.skip(1).map({ self!render($_, $dialect, False, $ignore) }).join('|') ~ ')'
        }
        when 'group' | 'scope' { '(?:' ~ self!render(@part[1], $dialect, False, $ignore) ~ ')' }
        when 'capture' {
            my $needed = so %*RED-REGEX-REFERENCED{@part[1]};
            if $needed {
                my Bool $boundary = False;
                self.walk(-> $node { $boundary = True if $node[0] eq 'match-boundary' }, @part[2]);
                self.unsupported('Capture references crossing Match boundaries are not supported')
                    if $boundary;
            }
            %*RED-REGEX-CAPTURES{@part[1]} = ++$*RED-REGEX-NEXT-CAPTURE if $needed;
            ($needed ?? '(' !! '(?:') ~ self!render(@part[2], $dialect, False, $ignore) ~ ')'
        }
        when 'backreference' {
            my @groups = @part[1].list.map({ %*RED-REGEX-CAPTURES{$_} }).grep(*.defined);
            self.unsupported('Forward or unmatched capture references are not supported')
                unless @groups;
            self.unsupported('PostgreSQL can only reference the first nine native capture groups')
                if $dialect eq 'Pg' && @groups.max > 9;
            self.unsupported('Exact references under :i are not implemented for PostgreSQL')
                if $dialect eq 'Pg' && $ignore;
            ($ignore ?? '(?-i:' !! '(?:') ~ @groups.map({ '\\' ~ $_ }).join('|') ~ ')'
        }
        when 'mode' {
            my $enabled = @part[1];
            self.unsupported('Scoped case modifiers are not supported by PostgreSQL')
                if $dialect eq 'Pg' && !$root;
            $dialect eq 'Pg'
                ?? ($enabled ?? '(?i)' !! '(?c)') ~ self!render(@part[2], $dialect, False, $enabled)
                !! '(?' ~ ($enabled ?? 'i' !! '-i') ~ ':'
                    ~ self!render(@part[2], $dialect, False, $enabled) ~ ')'
        }
        when 'intersection' {
            my Bool $same = False;
            self.walk(-> $node { $same = True if $node[0] eq 'same' }, @part);
            self.unsupported('MySQL same-character assertions combined with conjunction are not supported')
                if $same && $dialect eq 'MySQL';
            Red::Regex::Automaton.new(:tree(@part.List), :$ignore).render(
                -> $test, Bool $case {
                    if $test[0] eq 'empty' {
                        ''
                    } else {
                        my $label = $case == $ignore ?? $test !! ['mode', $case, $test];
                        self!render($label, $dialect, False, $ignore)
                    }
                })
        }
        when 'both' {
            my $left = @part[2] == $ignore ?? @part[1] !! ['mode', @part[2], @part[1]];
            my $right = @part[4] == $ignore ?? @part[3] !! ['mode', @part[4], @part[3]];
            '(?=' ~ self!render($left, $dialect, False, $ignore) ~ ')'
                ~ self!render($right, $dialect, False, $ignore)
        }
        when 'atomic' {
            self.unsupported("Atomic/ratcheted regexes are not supported by $dialect")
                unless $dialect eq 'MySQL';
            '(?>' ~ self!render(@part[1], $dialect, False, $ignore) ~ ')'
        }
        when 'any' { '.' }
        when 'class' {
            my %classes = digit => '[:digit:]', word => '[:alnum:]_', space => '[:space:]',
                alpha => '[:alpha:]_', alnum => '[:alnum:]_', lower => '[:lower:]',
                upper => '[:upper:]', xdigit => '0-9A-Fa-f', blank => '[:blank:]',
                cntrl => '[:cntrl:]', graph => '[:graph:]', print => '[:print:]',
                punct => '[:punct:]';
            self.unsupported("Unknown character class: {@part[1]}")
                unless %classes{@part[1]}:exists;
            '[' ~ (@part[2] ?? '^' !! '') ~ %classes{@part[1]} ~ ']'
        }
        when 'ranges' {
            my &escape = -> Int:D $point {
                $point <= 0xFFFF ?? '\u' ~ $point.fmt('%04X')
                    !! '\U' ~ $point.fmt('%08X')
            };
            # An empty Unicode category is a valid set that matches no character.
            return '(?!)' unless @part[1].elems || @part[2];
            return '.' unless @part[1].elems;
            '[' ~ (@part[2] ?? '^' !! '') ~ @part[1].map({
                escape(.[0]) ~ (.[0] == .[1] ?? '' !! '-' ~ escape(.[1]))
            }).join ~ ']'
        }
        when 'set' {
            my $left = self!render(@part[2], $dialect, False, $ignore);
            my $right = self!render(@part[3], $dialect, False, $ignore);
            @part[1] eq 'union' ?? '(?:' ~ $left ~ '|' ~ $right ~ ')'
                !! @part[1] eq 'intersect' ?? '(?=' ~ $left ~ ')' ~ $right
                !! '(?!' ~ $right ~ ')' ~ $left
        }
        when 'characters' {
            my $positive = '(?:' ~ @part[1].ords.map({ self.escape(.chr) }).join('|') ~ ')';
            @part[2] ?? '(?!' ~ $positive ~ ').' !! $positive
        }
        when 'same' {
            self.unsupported('The same-character assertion requires MySQL') unless $dialect eq 'MySQL';
            my $slot = ++$*RED-REGEX-NEXT-CAPTURE;
            # Raku's same assertion compares exactly, even under :i.
            my $test = '(?-i:(?<=(.))(?=\\' ~ $slot ~ '))';
            @part[1] ?? '(?!' ~ $test ~ ')' !! $test
        }
        when 'anchor' {
            my $end = $dialect eq 'Pg' ?? '\Z' !! '\z';
            given @part[1] {
                when 'begin' { '\A' }
                when 'end' { $end }
                when 'line-begin' { '(?:\A|(?<=\n))' }
                when 'line-end' { '(?:' ~ $end ~ '|(?=\n))' }
                when 'word-left' { $dialect eq 'Pg' ?? '\m' !! '(?<!\w)(?=\w)' }
                when 'word-right' { $dialect eq 'Pg' ?? '\M' !! '(?<=\w)(?!\w)' }
                when 'word' { $dialect eq 'Pg' ?? '\y' !! '\b' }
                when 'not-word' { $dialect eq 'Pg' ?? '\Y' !! '\B' }
                when 'not-within-word' { '(?:(?<!\w)|(?!\w))' }
                when 'within-word' { '(?<=\w)(?=\w)' }
                default { self.unsupported("Unknown anchor: {@part[1]}") }
            }
        }
        when 'look' {
            my $has-reference = False;
            self.walk(-> $part { $has-reference = True if $part[0] eq 'backreference' }, @part[3]);
            self.unsupported('PostgreSQL lookarounds cannot contain backreferences')
                if $dialect eq 'Pg' && $has-reference;
            self.unsupported('MySQL requires a bounded lookbehind')
                if $dialect eq 'MySQL' && @part[1] eq 'after'
                    && self.maximum-width(@part[3]) == Inf;
            '(' ~ (@part[1] eq 'after' ?? '?<' !! '?') ~ (@part[2] ?? '!' !! '=')
                ~ self!render(@part[3], $dialect, False, $ignore) ~ ')'
        }
        when 'repeat' {
            my ($body, $minimum, $maximum, $frugal) = @part[1..4];
            if $dialect eq 'Pg' && ($minimum > 255 || $maximum > 255) {
                my Bool $referenced-capture = False;
                self.walk(-> $part {
                    $referenced-capture = True if $part[0] eq 'capture'
                        && %*RED-REGEX-REFERENCED{$part[1]};
                }, $body);
                self.unsupported('Large repetition cannot duplicate referenced capture groups')
                    if $referenced-capture;
                my $atom = '(?:' ~ self!render($body, $dialect, False, $ignore) ~ ')';
                return self.pg-repeat($atom, $minimum, $maximum, $frugal);
            }
            my $suffix = $minimum == 0 && $maximum == -1 ?? '*'
                !! $minimum == 1 && $maximum == -1 ?? '+'
                !! $minimum == 0 && $maximum == 1 ?? '?'
                !! '{' ~ $minimum ~ ',' ~ ($maximum == -1 ?? '' !! $maximum) ~ '}';
            '(?:' ~ self!render($body, $dialect, False, $ignore) ~ ')' ~ $suffix ~ ($frugal ?? '?' !! '')
        }
        default { self.unsupported("Unsupported operation {@part[0]} on $dialect") }
    }
}

# Lower large bounds without emitting any native bound greater than 255.
method pg-repeat(Str:D $atom, Int:D $minimum, Int:D $maximum,
    Bool:D $frugal --> Str:D) {
    my $preference = $frugal ?? '?' !! '';
    sub exact(Str:D $unit, Int:D $count, Int:D $depth = 0 --> Str:D) {
        self.unsupported('PostgreSQL repetition lowering exceeds 16 nesting levels')
            if $depth > 16;
        return '' if $count == 0;
        return $unit ~ '{' ~ $count ~ '}' ~ $preference if $count <= 255;
        my $block = '(?:' ~ $unit ~ '{255}' ~ $preference ~ ')';
        exact($block, $count div 255, $depth + 1)
            ~ exact($unit, $count % 255, $depth + 1)
    }
    my $pattern = exact($atom, $minimum);
    if $maximum == -1 {
        $pattern ~= $atom ~ '*' ~ $preference;
    } else {
        my $optional = $maximum - $minimum;
        my $block = '(?:' ~ $atom ~ '{0,255}' ~ $preference ~ ')';
        $pattern ~= exact($block, $optional div 255);
        $pattern ~= $atom ~ '{0,' ~ ($optional % 255) ~ '}' ~ $preference
            if $optional % 255;
    }
    self.unsupported('PostgreSQL repetition lowering exceeds 64KiB of pattern text')
        if $pattern.chars > 65536;
    '(?:' ~ $pattern ~ ')'
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
    sub replace($tree) {
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
