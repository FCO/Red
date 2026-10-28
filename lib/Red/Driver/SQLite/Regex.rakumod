use Red::Regex;
use Red::Regex::Automaton;
use X::Red::Exceptions;

#| Thompson NFA evaluated by a recursive CTE. No SQLite regexp extension or Raku
#| callback is required. UNION deduplicates epsilon cycles and matching states.
unit class Red::Driver::SQLite::Regex;

has Red::Regex $.regex is required;
has Bool $.ignore = False;

method test($tree, Bool:D $ignore, &bind, &assertion --> Str:D) {
    my $character = 'substr(i.value, r.pos, 1)';
    my $previous = 'substr(i.value, r.pos - 1, 1)';
    my &equal = -> Str $left, Str $right {
        $ignore ?? "lower($left) = lower($right) COLLATE BINARY"
            !! "$left = $right COLLATE BINARY"
    };
    my &word = -> Str $text { "$text GLOB '[A-Za-z0-9_]'" };
    given $tree[0] {
        when 'empty' | 'any' { '1' }
        when 'literal' { equal($character, bind($tree[1])) }
        when 'both' {
            my $left = self.test($tree[1], $tree[2], &bind, &assertion);
            my $right = self.test($tree[3], $tree[4], &bind, &assertion);
            "($left AND $right)"
        }
        when 'ranges' {
            return $tree[2] ?? '1' !! '0' unless $tree[1].elems;
            my @codepoints = "unicode($character)";
            @codepoints.append: "unicode(lower($character))", "unicode(upper($character))"
                if $ignore;
            my @ranges = @codepoints.map(-> $point {
                |$tree[1].map({ "$point BETWEEN {.[0]} AND {.[1]}" })
            });
            my $test = self.disjunction(@ranges);
            $tree[2] ?? "NOT ($test)" !! $test
        }
        when 'set' {
            my $left = self.test($tree[2], $ignore, &bind, &assertion);
            my $right = self.test($tree[3], $ignore, &bind, &assertion);
            $tree[1] eq 'union' ?? "($left OR $right)" !! "($left AND NOT ($right))"
        }
        when 'characters' {
            my $characters = bind($tree[1]);
            my $test = $ignore
                ?? "instr(lower($characters), lower($character)) > 0"
                !! "instr($characters, $character) > 0";
            $tree[2] ?? "NOT ($test)" !! $test
        }
        when 'class' {
            my %classes = digit => '[0-9]', word => '[A-Za-z0-9_]',
                alpha => '[A-Za-z_]', alnum => '[A-Za-z0-9_]', lower => '[a-z]',
                upper => '[A-Z]', xdigit => '[0-9A-Fa-f]',
                space => "[ \t\n\r\x[B]\f]", blank => "[ \t]",
                graph => '[!-~]', print => '[ -~]';
            if $tree[1] eq any(<cntrl punct>) {
                my @ranges = $tree[1] eq 'cntrl'
                    ?? ([1, 31], [127, 127])
                    !! ([33, 47], [58, 64], [91, 96], [123, 126]);
                my $test = @ranges.map({
                    "unicode($character) BETWEEN {.[0]} AND {.[1]}"
                }).join(' OR ');
                return $tree[2] ?? "NOT ($test)" !! "($test)";
            }
            $!regex.unsupported("Unknown SQLite character class {$tree[1]}")
                unless %classes{$tree[1]}:exists;
            my $text = $ignore && $tree[1] eq any(<lower upper>)
                ?? "lower($character)" !! $character;
            my $pattern = $ignore && $tree[1] eq 'upper' ?? '[a-z]' !! %classes{$tree[1]};
            my $test = "$text GLOB {bind($pattern)}";
            $tree[2] ?? "NOT ($test)" !! $test
        }
        when 'same' {
            my $test = "(r.pos > 1 AND r.pos <= length(i.value)"
                ~ " AND $previous = $character COLLATE BINARY)";
            $tree[1] ?? "NOT ($test)" !! $test
        }
        when 'anchor' {
            given $tree[1] {
                when 'begin' { 'r.pos = 1' }
                when 'end' { 'r.pos = length(i.value) + 1' }
                when 'line-begin' { "(r.pos = 1 OR $previous = char(10))" }
                when 'line-end' { "(r.pos = length(i.value) + 1 OR $character = char(10))" }
                when 'word-left' { "(NOT ({word($previous)}) AND {word($character)})" }
                when 'word-right' { "({word($previous)} AND NOT ({word($character)}))" }
                when 'word' { "(({word($previous)}) <> ({word($character)}))" }
                when 'not-word' { "(({word($previous)}) = ({word($character)}))" }
                when 'not-within-word' { "NOT ({word($previous)} AND {word($character)})" }
                when 'within-word' { "({word($previous)} AND {word($character)})" }
                default { $!regex.unsupported("Unknown SQLite anchor {$tree[1]}") }
            }
        }
        when 'look' {
            my $literal = $!regex.literal-text($tree[3]);
            return assertion($tree, $ignore) unless $literal.defined;
            my $length = $literal.ords.elems;
            my $offset = $tree[1] eq 'after' ?? "r.pos - $length" !! 'r.pos';
            my $test = equal("substr(i.value, $offset, $length)", bind($literal));
            $test = "(r.pos > $length AND $test)" if $tree[1] eq 'after';
            $tree[2] ?? "NOT ($test)" !! $test
        }
        default { $!regex.unsupported("Unknown SQLite transition {$tree[0]}") }
    }
}

# Keep generated predicates balanced rather than exceeding SQLite's expression
# depth limit with a long, left-associated OR chain.
method disjunction(@tests --> Str:D) {
    return @tests[0] if @tests.elems == 1;
    my $middle = @tests.elems div 2;
    '(' ~ self.disjunction(@tests.head($middle)) ~ ' OR '
        ~ self.disjunction(@tests.skip($middle)) ~ ')'
}

method clauses(Str:D $prefix, &bind, &name, Bool :$origin = False --> List:D) {
    my $graph = Red::Regex::Automaton.new(:tree($!regex.tree), :ignore($!ignore)).graph;
    my ($start, $end) = $graph<start accept>;
    my @edges = $graph<edges>.list;
    my @clauses;
    my %assertion-sql;
    my &assertion = -> $tree, Bool $ignore {
        my $key = $tree.WHICH.Str ~ '|' ~ $ignore;
        if %assertion-sql{$key}:exists {
            %assertion-sql{$key}
        } else {
            my $child-prefix = name();
            my $child = self.WHAT.new(
                :regex(Red::Regex.new(:tree($tree[3].List))), :$ignore);
            my ($clauses, $accept) = $child.clauses($child-prefix, &bind, &name, :origin);
            @clauses.append: $clauses.list;
            my $position = $tree[1] eq 'before' ?? 'origin' !! 'pos';
            %assertion-sql{$key} = "r.pos " ~ ($tree[2] ?? 'NOT IN' !! 'IN')
                ~ " (SELECT $position FROM {$child-prefix}_states WHERE pc = $accept)"
        }
    };
    # Child CTEs appear before parent predicates in SQL, so collect their binds first.
    for @edges -> $edge {
        my $test = $edge[3];
        assertion($test, $edge[4]) if $test[0] eq 'look'
            && !$!regex.literal-text($test[3]).defined;
    }
    my @rows;
    my @tests;
    for @edges.kv -> $id, $edge {
        my ($from, $to, $step, $test, $ignore) = $edge.list;
        @rows.push: "($id, $from, $to, $step)";
        @tests.push: "(e.id = $id AND {self.test($test, $ignore, &bind, &assertion)})";
    }
    @clauses.push: "{$prefix}_edges(id, src, dst, step) AS (VALUES {@rows.join(', ')})";
    my $origin-column = $origin ?? ', origin' !! '';
    my $origin-seed = $origin ?? ', pos' !! '';
    my $origin-step = $origin ?? ', r.origin' !! '';
    @clauses.push: qq:to/SQL/.trim;
        {$prefix}_states(pc, pos$origin-column) AS (
            SELECT $start, pos$origin-seed FROM _red_rx_positions
            UNION
            SELECT e.dst, r.pos + e.step$origin-step
            FROM {$prefix}_states r
            JOIN {$prefix}_edges e ON e.src = r.pc
            CROSS JOIN _red_rx_input i
            WHERE r.pos + e.step <= length(i.value) + 1
                AND {self.disjunction(@tests)}
        )
        SQL
    (@clauses.List, $end)
}

method translate(Pair:D $subject --> Pair:D) {
    my @bind = |$subject.value;
    my &bind = -> Str:D $value {
        $!regex.unsupported('SQLite regex does not support NUL characters') if $value.contains("\0");
        @bind.push: $value;
        '?'
    };
    my Int $next-name = 0;
    my &name = -> { '_red_rx_' ~ $next-name++ };
    my $prefix = name();
    my ($clauses, $accept) = self.clauses($prefix, &bind, &name);
    my $sql = qq:to/SQL/.trim;
        (WITH RECURSIVE
        _red_rx_input(value) AS (SELECT {$subject.key}),
        _red_rx_positions(pos) AS (
            SELECT 1
            UNION ALL
            SELECT pos + 1 FROM _red_rx_positions CROSS JOIN _red_rx_input i
            WHERE pos <= length(i.value)
        ),
        {$clauses.join(",\n")}
        SELECT CASE WHEN i.value IS NULL THEN NULL ELSE EXISTS (
            SELECT 1 FROM {$prefix}_states WHERE pc = $accept
        ) END FROM _red_rx_input i)
        SQL
    $sql => @bind
}
