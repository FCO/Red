use Red::Regex;
use Red::Regex::Unicode;
use X::Red::Exceptions;

#| Parse regex syntax without executing code or invoking user-defined rules.
unit class Red::Compiler::Regex;

has Bool $!sigspace = False;
has Bool $!ignore-case = False;
has Bool $!ratchet = False;
has %!active-rules;
has Int $!next-capture = 0;
has @!capture-slots;
has %!named-slots;
has %!unsafe-captures;
has @.literal-parameters;

method unsupported($node) {
    X::Red::Compiler::Unsupported.new(:fatal,
        :reason("Unsupported SQL regex syntax: {$node.^name}")).throw
}

method translate($quoted, Str:D :$dialect = 'Pg' --> Str:D) {
    self.compile($quoted).render(:$dialect)
}

method compile($quoted --> Red::Regex:D) {
    my $previous-sigspace = $!sigspace;
    my $previous-case = $!ignore-case;
    my $previous-ratchet = $!ratchet;
    my @previous-slots = @!capture-slots;
    my %previous-names = %!named-slots;
    my %previous-unsafe = %!unsafe-captures;
    my $previous-next = $!next-capture;
    LEAVE {
        $!sigspace = $previous-sigspace;
        $!ignore-case = $previous-case;
        $!ratchet = $previous-ratchet;
        @!capture-slots = @previous-slots;
        %!named-slots = %previous-names;
        %!unsafe-captures = %previous-unsafe;
        $!next-capture = $previous-next;
    }
    @!capture-slots = ();
    %!named-slots = ();
    @!literal-parameters = ();
    %!unsafe-captures = ();
    $!next-capture = 0;
    my $declaration = $quoted.^name eq any(<RakuAST::RegexDeclaration
        RakuAST::TokenDeclaration RakuAST::RuleDeclaration>);
    self.unsupported($quoted) unless $declaration || $quoted.^name eq 'RakuAST::QuotedRegex';
    self.unsupported($quoted) if !$declaration && $quoted.match-immediately;
    my $ignore-case;
    $!sigspace = False;
    $!ignore-case = False;
    $!ratchet = False;
    for ($declaration ?? () !! $quoted.adverbs) -> $adverb {
        self.unsupported($adverb) unless $adverb.^name eq any(<
            RakuAST::ColonPair::True RakuAST::ColonPair::False>)
            && $adverb.key eq any(<i ignorecase s sigspace r ratchet>);
        my $enabled = $adverb.^name eq 'RakuAST::ColonPair::True';
        if $adverb.key eq any(<s sigspace>) {
            $!sigspace = $enabled;
        } elsif $adverb.key eq any(<r ratchet>) {
            $!ratchet = $enabled;
        } else {
            $ignore-case = $enabled;
            $!ignore-case = $enabled;
        }
    }
    my @tree = ($declaration ?? self.inline-rule($quoted, :root) !! self.node($quoted.body)).list;
    @tree = ['mode', $ignore-case, @tree.Array] if $ignore-case.defined;
    my $regex = Red::Regex.new(:tree(@tree.List),
        :capture-slots(@!capture-slots.List), :named-slots(%!named-slots.Map),
        :unsafe-captures(%!unsafe-captures.keys.List));
    my $intersection = False;
    my $references = False;
    $regex.walk(-> $part {
        $intersection = True if $part[0] eq 'intersection';
        $references = True if $part[0] eq 'backreference';
        if $part[0] eq 'backreference'
            && $part[1].list.grep({ %!unsafe-captures{$_}:exists }) {
            X::Red::Compiler::Unsupported.new(:fatal, :reason(
                'Backreferences to repeated capture lists are not supported'
            )).throw;
        }
    });
    X::Red::Compiler::Unsupported.new(:fatal,
        :reason('Capture references combined with regex conjunction are not supported')).throw
        if $intersection && $references;
    $regex
}

method sequence(@terms --> Array:D) {
    my $previous-sigspace = $!sigspace;
    my $previous-case = $!ignore-case;
    my $previous-ratchet = $!ratchet;
    LEAVE {
        $!sigspace = $previous-sigspace;
        $!ignore-case = $previous-case;
        $!ratchet = $previous-ratchet;
    }
    my @parts;
    for @terms.kv -> $index, $term {
        if $term.^name eq 'RakuAST::Regex::InternalModifier::Ratchet' {
            $!ratchet = !$term.negated;
            next;
        }
        if $term.^name eq 'RakuAST::Regex::InternalModifier::Sigspace' {
            $!sigspace = !$term.negated;
            next;
        }
        if $term.^name eq 'RakuAST::Regex::InternalModifier::IgnoreCase' {
            $!ignore-case = !$term.negated;
            @parts.push: ['mode', $!ignore-case, self.sequence(@terms.skip($index + 1))];
            last;
        }
        @parts.push: self.node($term);
    }
    return ['empty'] unless @parts;
    return @parts[0] if @parts.elems == 1;
    ['sequence', |@parts]
}

method node($node --> Array:D) {
    given $node.^name {
        when 'RakuAST::Regex::Sequence' { self.sequence($node.terms) }
        when 'RakuAST::Regex::WithWhitespace' {
            my @body = self.node($node.regex).list;
            $!sigspace ?? ['sequence', @body.Array, self.whitespace] !! @body.Array
        }
        when 'RakuAST::Regex::Literal' { ['literal', $node.text] }
        when 'RakuAST::Regex::Term' { ['empty'] }
        when 'RakuAST::Regex::MatchFrom' { ['match-boundary', 'from'] }
        when 'RakuAST::Regex::MatchTo' { ['match-boundary', 'to'] }
        when 'RakuAST::Regex::Quote' {
            my $quote = $node.quoted;
            self.unsupported($quote) unless $quote.^name eq 'RakuAST::QuotedString';
            if $quote.processors.elems {
                self.unsupported($quote) unless $quote.processors.grep({
                    $_ ne any(<words val>)
                }).elems == 0 && $quote.segments.map(*.^name).all eq 'RakuAST::StrLiteral';
                my $text = $quote.segments.map(*.compile-time-value).join;
                my @values = $quote.processors.grep(* eq 'words') ?? $text.words !! ($text,);
                @values = @values.map({ val($_) }) if $quote.processors.grep(* eq 'val');
                return ['alternative', |@values.map({ ['literal', .Str] })] if @values;
                return ['never'];
            }
            my @parts = $quote.segments.map(-> $part {
                $part.^name eq 'RakuAST::StrLiteral'
                    ?? ['literal', $part.compile-time-value] !! self.literal-parameter($part, :quoted)
            });
            @parts.elems == 1 ?? @parts[0] !! ['sequence', |@parts]
        }
        when 'RakuAST::Regex::Interpolation' { self.literal-parameter($node.var) }
        when 'RakuAST::Regex::InternalModifier::Ratchet' { ['empty'] }
        when 'RakuAST::Regex::InternalModifier::IgnoreCase' {
            ['mode', !$node.negated, ['empty']]
        }
        when 'RakuAST::Regex::Anchor::BeginningOfString' { ['anchor', 'begin'] }
        when 'RakuAST::Regex::Anchor::EndOfString' { ['anchor', 'end'] }
        when 'RakuAST::Regex::Anchor::BeginningOfLine' { ['anchor', 'line-begin'] }
        when 'RakuAST::Regex::Anchor::EndOfLine' { ['anchor', 'line-end'] }
        when 'RakuAST::Regex::Anchor::LeftWordBoundary' { ['anchor', 'word-left'] }
        when 'RakuAST::Regex::Anchor::RightWordBoundary' { ['anchor', 'word-right'] }
        when 'RakuAST::Regex::CharClass::Any' { ['any'] }
        when 'RakuAST::Regex::CharClass::Digit' { ['class', 'digit', $node.negated] }
        when 'RakuAST::Regex::CharClass::Word' { ['class', 'word', $node.negated] }
        when 'RakuAST::Regex::CharClass::Space' { ['class', 'space', $node.negated] }
        when 'RakuAST::Regex::CharClass::Tab' { ['characters', "\t", $node.negated] }
        when 'RakuAST::Regex::CharClass::HorizontalSpace' {
            ['characters', "\t \x[A0]\x[1680]" ~ (0x2000..0x200A).map(*.chr).join
                ~ "\x[202F]\x[205F]\x[3000]", $node.negated]
        }
        when 'RakuAST::Regex::CharClass::VerticalSpace' {
            ['characters', "\n\r\x[B]\f\x[85]\x[2028]\x[2029]", $node.negated]
        }
        when 'RakuAST::Regex::CharClass::Newline' {
            my @characters = ['characters', "\n\r\x[B]\f\x[85]\x[2028]\x[2029]",
                $node.negated];
            $node.negated ?? @characters.Array
                !! ['alternative', ['literal', "\r\n"], @characters.Array]
        }
        when 'RakuAST::Regex::Group' {
            my $previous-sigspace = $!sigspace;
            LEAVE $!sigspace = $previous-sigspace;
            ['group', self.node($node.regex)]
        }
        when 'RakuAST::Regex::CapturingGroup' {
            my $capture = $!next-capture++;
            @!capture-slots.push: ($capture,).List;
            my @outer = @!capture-slots;
            my %outer-names = %!named-slots;
            my $previous-sigspace = $!sigspace;
            my $previous-case = $!ignore-case;
            my $previous-ratchet = $!ratchet;
            LEAVE {
                @!capture-slots = @outer;
                %!named-slots = %outer-names;
                $!sigspace = $previous-sigspace;
                $!ignore-case = $previous-case;
                $!ratchet = $previous-ratchet;
            }
            @!capture-slots = ();
            %!named-slots = ();
            ['capture', $capture, ['scope', self.node($node.regex)]]
        }
        when 'RakuAST::Regex::NamedCapture' {
            my $body = $node.regex;
            my Bool $scoped = $body.^name eq 'RakuAST::Regex::CapturingGroup';
            my @outer = @!capture-slots;
            my %outer-names = %!named-slots;
            LEAVE {
                if $scoped {
                    @!capture-slots = @outer;
                    %!named-slots = %outer-names;
                }
            }
            self.unsupported($node) if $node.array || (%!named-slots{$node.name}:exists)
                || ($body.^name eq 'RakuAST::Regex::QuantifiedAtom'
                    && $body.atom.^name eq 'RakuAST::Regex::CapturingGroup');
            my $capture = $!next-capture++;
            %!named-slots{$node.name} = ($capture,).List;
            if $scoped {
                %outer-names = %!named-slots;
                @!capture-slots = ();
                %!named-slots = ();
                # Named parentheses introduce a scope without a parent positional slot.
                $body = $body.regex;
            }
            my $content = self.node($body);
            ['capture', $capture, $scoped ?? ['scope', $content] !! $content]
        }
        when 'RakuAST::Regex::Assertion::Alias' {
            self.unsupported($node) if %!named-slots{$node.name}:exists;
            my $capture = $!next-capture++;
            %!named-slots{$node.name} = ($capture,).List;
            ['capture', $capture, self.node($node.assertion)]
        }
        when 'RakuAST::Regex::BackReference::Named' {
            self.unsupported($node) unless %!named-slots{$node.name}:exists;
            ['backreference', %!named-slots{$node.name}]
        }
        when 'RakuAST::Regex::BackReference::Positional' {
            self.unsupported($node) unless $node.index ~~ Int:D
                && 0 <= $node.index < @!capture-slots.elems;
            ['backreference', @!capture-slots[$node.index]]
        }
        when 'RakuAST::Regex::Alternation' | 'RakuAST::Regex::SequentialAlternation' {
            my @base = @!capture-slots;
            my %base-names = %!named-slots;
            my %merged-names = %base-names;
            my @merged = @base;
            my @parts;
            LEAVE {
                @!capture-slots = @merged;
                %!named-slots = %merged-names;
            }
            for $node.branches -> $branch {
                @!capture-slots = @base;
                %!named-slots = %base-names;
                @parts.push: self.node($branch);
                for @!capture-slots.kv -> $index, $slots {
                    my @existing = (@merged[$index] // ()).list;
                    @merged[$index] = (|@existing, |$slots.list).unique.List;
                }
                for %!named-slots.kv -> $name, $slots {
                    my @existing = (%merged-names{$name} // ()).list;
                    %merged-names{$name} = (|@existing, |$slots.list).unique.List;
                }
            }
            ['alternative', |@parts]
        }
        when 'RakuAST::Regex::Conjunction' | 'RakuAST::Regex::SequentialConjunction' {
            ['intersection', |$node.branches.map({ self.node($_) })]
        }
        when 'RakuAST::Regex::Assertion::Lookahead' {
            my @outer-slots = @!capture-slots;
            my %outer-names = %!named-slots;
            LEAVE {
                @!capture-slots = @outer-slots;
                %!named-slots = %outer-names;
            }
            my $assertion = $node.assertion;
            if $assertion.^name eq 'RakuAST::Regex::Assertion::Named::Args' {
                my @body = self.position-assertion($assertion).list;
                @body[2] = $node.negated;
                return @body.Array;
            }
            self.unsupported($node) unless $assertion.^name eq any(<
                RakuAST::Regex::Assertion::Named RakuAST::Regex::Assertion::Named::RegexArg>);
            my $name = $assertion.name.canonicalize;
            if $assertion.^name eq 'RakuAST::Regex::Assertion::Named' {
                my @body = self.named-assertion($assertion).list;
                if @body[0] eq 'same' {
                    @body[1] = $node.negated;
                    return @body.Array;
                }
                return ['look', 'before', $node.negated, @body.Array];
            }
            self.unsupported($node) unless $name eq any(<before after>)
                && $assertion.^name eq 'RakuAST::Regex::Assertion::Named::RegexArg';
            @!capture-slots = ();
            %!named-slots = ();
            my @body = self.node($assertion.regex-arg).list;
            ['look', $name, $node.negated, @body.Array]
        }
        when 'RakuAST::Regex::Assertion::Named' {
            self.capture-assertion($node, self.named-assertion($node))
        }
        when 'RakuAST::Regex::Assertion::Named::Args' {
            self.capture-assertion($node, self.position-assertion($node))
        }
        when 'RakuAST::Regex::QuantifiedAtom' {
            my $quantifier = $node.quantifier;
            self.unsupported($quantifier) unless $quantifier.backtrack.^name eq any(<
                RakuAST::Regex::Backtrack RakuAST::Regex::Backtrack::Frugal
                RakuAST::Regex::Backtrack::Ratchet>);
            my $frugal = $quantifier.backtrack.^name.ends-with('::Frugal');
            my $atomic = ($!ratchet && !$frugal)
                || $quantifier.backtrack.^name.ends-with('::Ratchet');
            my &wrap = -> @tree { $atomic ?? ['atomic', @tree.Array] !! @tree.Array };
            my ($minimum, $maximum) = do given $quantifier.^name {
                when 'RakuAST::Regex::Quantifier::ZeroOrMore' { 0, -1 }
                when 'RakuAST::Regex::Quantifier::OneOrMore' { 1, -1 }
                when 'RakuAST::Regex::Quantifier::ZeroOrOne' { 0, 1 }
                when 'RakuAST::Regex::Quantifier::Range' {
                    self.unsupported($quantifier) unless $quantifier.min ~~ Int:D
                        && (!$quantifier.max.defined || $quantifier.max ~~ Int:D);
                    my $min = $quantifier.min + $quantifier.excludes-min.Int;
                    my $max = $quantifier.max.defined
                        ?? $quantifier.max - $quantifier.excludes-max.Int !! -1;
                    self.unsupported($quantifier) unless $min >= 0
                        && ($max == -1 || $max >= $min);
                    $min, $max
                }
                default { self.unsupported($quantifier) }
            };
            my @body = self.node($node.atom).list;
            if $maximum == -1 || $maximum > 1 {
                if $maximum == -1 {
                    my $pattern = Red::Regex.new(:tree(@body.List));
                    my Bool $reference = False;
                    $pattern.walk(-> $part { $reference = True if $part[0] eq 'backreference' });
                    X::Red::Compiler::Unsupported.new(:fatal, :reason(
                        'Unbounded zero-width repetition with capture references is not supported'
                    )).throw if $reference && $pattern.maximum-width == 0;
                }
                self.mark-unsafe-captures(@body);
            }
            return wrap(['repeat', @body.Array, $minimum, $maximum, $frugal])
                if $node.separator.^name eq 'RakuAST::Regex::Term';
            my @separator = self.node($node.separator).list;
            my @tail = ['repeat', ['sequence', @separator.Array, @body.Array],
                ($minimum max 1) - 1, $maximum == -1 ?? -1 !! $maximum - 1, $frugal];
            return ['empty'] if $maximum == 0;
            my @separated = ['sequence', @body.Array, @tail.Array];
            @separated.push: ['repeat', @separator.Array, 0, 1, $frugal]
                if $node.trailing-separator;
            wrap($minimum == 0
                ?? ['repeat', @separated.Array, 0, 1, $frugal] !! @separated.Array)
        }
        when 'RakuAST::Regex::Assertion::CharClass' {
            my @result;
            for $node.elements -> $element {
                my @part = self.class-element($element).list;
                if @result {
                    @result = ['set', $element.negated ?? 'subtract' !! 'union',
                        @result.Array, @part.Array];
                } else {
                    @result = $element.negated
                        ?? ['set', 'subtract', ['any'], @part.Array] !! @part.Array;
                }
            }
            self.unsupported($node) unless @result;
            @result.Array
        }
        default { self.unsupported($node) }
    }
}

method class-element($element --> Array:D) {
    given $element.^name {
        when 'RakuAST::Regex::CharClassElement::Enumeration' {
            my @characters;
            my @ranges;
            for $element.elements -> $entry {
                given $entry.^name {
                    when 'RakuAST::Regex::CharClassEnumerationElement::Character' {
                        self.unsupported($entry) if $entry.character.contains("\0");
                        @characters.push: $entry.character;
                    }
                    when 'RakuAST::Regex::CharClassEnumerationElement::Range' {
                        self.unsupported($entry) unless 0 <= $entry.from <= $entry.to <= 0x10FFFF;
                        my $from = $entry.from max 1;
                        my $to = $entry.to;
                        if $to - $from <= 128 && ($to < 0xD800 || $from > 0xDFFF) {
                            @characters.append: ($from .. $to).map(*.chr);
                        } else {
                            @ranges.push: ($from, $to min 0xD7FF).List
                                if $from <= 0xD7FF;
                            @ranges.push: ($from max 0xE000, $to).List
                                if $to >= 0xE000;
                        }
                    }
                    default { self.unsupported($entry) }
                }
            }
            my @parts;
            @parts.push: ['characters', @characters.join, False] if @characters;
            @parts.push: ['ranges', @ranges.List, False] if @ranges;
            return ['ranges', ().List, False] unless @parts;
            @parts.elems == 1 ?? @parts[0] !! ['alternative', |@parts]
        }
        when 'RakuAST::Regex::CharClassElement::Property' {
            my $value = Str;
            if $element.predicate.defined {
                my $predicate = $element.predicate;
                if $predicate.^name eq 'RakuAST::Circumfix::Parentheses' {
                    my @statements = $predicate.semilist.statements;
                    self.unsupported($predicate) unless @statements.elems == 1
                        && @statements[0].^name eq 'RakuAST::Statement::Expression';
                    $predicate = @statements[0].expression;
                }
                self.unsupported($predicate) unless $predicate.^name eq 'RakuAST::QuotedString'
                    && $predicate.segments.map(*.^name).all eq 'RakuAST::StrLiteral'
                    && $predicate.processors.grep({ $_ ne any(<words val>) }).elems == 0;
                my $text = $predicate.segments.map(*.compile-time-value).join;
                if $predicate.processors.grep(* eq 'words') {
                    self.unsupported($predicate) unless $text.words.elems == 1;
                    $text = $text.words[0];
                }
                $value = $text;
            }
            ['ranges', property-ranges($element.property, :$value), $element.inverted]
        }
        default { self.unsupported($element) }
    }
}

method capture-assertion($node, @body --> Array:D) {
    return @body.Array unless $node.capturing;
    my $name = $node.name.canonicalize;
    my $capture = $!next-capture++;
    my @existing = (%!named-slots{$name} // ()).list;
    if @existing {
        %!unsafe-captures{$_} = True for |@existing, $capture;
    }
    %!named-slots{$name} = (|@existing, $capture).List;
    ['capture', $capture, @body.Array]
}

method position-assertion($node --> Array:D) {
    self.unsupported($node) unless $node.name.canonicalize eq 'at';
    for $node.get-implicit-lookups.grep(*.is-resolved) -> $lookup {
        self.unsupported($node) unless $lookup.resolution.^name
            eq 'RakuAST::Declaration::External::Setting';
    }
    my @arguments = $node.args.args;
    self.unsupported($node) unless @arguments.elems == 1
        && @arguments[0].^name eq 'RakuAST::IntLiteral';
    my Int $position = @arguments[0].compile-time-value;
    self.unsupported($node) if $position < 0;
    ['look', 'after', False, ['sequence', ['anchor', 'begin'],
        ['repeat', ['any'], $position, $position, False]]]
}

method named-assertion($node --> Array:D) {
    my @resolved = $node.get-implicit-lookups.grep(*.is-resolved);
    for @resolved -> $lookup {
        return self.inline-rule($lookup.resolution)
            if $lookup.resolution.^name eq any(<RakuAST::RegexDeclaration
                RakuAST::TokenDeclaration RakuAST::RuleDeclaration>);
        self.unsupported($node) unless $lookup.resolution.^name
            eq 'RakuAST::Declaration::External::Setting';
    }
    my $name = $node.name.canonicalize;
    return ['same', False] if $name eq 'same';
    return self.whitespace if $name eq 'ws';
    return ['anchor', 'word'] if $name eq 'wb';
    return ['anchor', 'within-word'] if $name eq 'ww';
    return ['sequence', ['class', 'alpha', False],
        ['atomic', ['repeat', ['class', 'word', False], 0, -1, False]]]
        if $name eq 'ident';
    self.unsupported($node) unless $name eq any(<digit word space alpha alnum lower upper
        xdigit blank cntrl graph print punct>);
    return ['ranges', property-ranges('P'), False] if $name eq 'punct';
    return ['alternative', ['class', 'alnum', False],
        ['ranges', property-ranges('P'), False]] if $name eq 'graph';
    ['class', $name, False]
}

method whitespace(--> Array:D) {
    ['sequence', ['anchor', 'not-within-word'],
        ['repeat', ['class', 'space', False], 0, -1, False],
        ['look', 'before', True, ['class', 'space', False]]]
}

method inline-rule($declaration, Bool :$root = False --> Array:D) {
    my $previous-sigspace = $!sigspace;
    my $previous-case = $!ignore-case;
    my $previous-ratchet = $!ratchet;
    my @outer-slots = @!capture-slots;
    my %rule-outer-names = %!named-slots;
    my $key = $declaration.WHERE.Str;
    my Bool $entered = False;
    LEAVE {
        %!active-rules{$key}:delete if $entered;
        unless $root {
            @!capture-slots = @outer-slots;
            %!named-slots = %rule-outer-names;
        }
        $!sigspace = $previous-sigspace;
        $!ignore-case = $previous-case;
        $!ratchet = $previous-ratchet;
    }
    self.unsupported($declaration) if $declaration.signature.parameters.elems
        || $declaration.traits.elems || $declaration.has-any-phasers;
    X::Red::Compiler::Unsupported.new(:fatal,
        :reason('Recursive named regex rules are not supported by the SQL compiler')).throw
        if %!active-rules{$key}:exists;
    %!active-rules{$key} = True;
    $entered = True;
    @!capture-slots = ();
    %!named-slots = ();
    $!sigspace = $declaration.declarator eq 'rule';
    $!ratchet = so $declaration.declarator eq any(<token rule>);
    $!ignore-case = False;
    my @body = self.node($declaration.body).list;
    # Named regexes have their own lexical case mode, unlike bracket groups.
    my $scope = ['scope', @body.Array];
    $previous-case ?? ['mode', False, $scope] !! $scope
}

method mark-unsafe-captures(@tree) {
    Red::Regex.new(:tree(@tree.List)).walk(-> $part {
        %!unsafe-captures{$part[1]} = True if $part[0] eq 'capture';
    }, :!descend-capture-scopes);
    Nil
}

method literal-parameter($variable, Bool :$quoted = False --> Array:D) {
    my $source = $variable;
    if $quoted && $source.^name eq 'RakuAST::ApplyPostfix' {
        my $postfix = $source.postfix;
        self.unsupported($variable) unless $postfix.^name eq 'RakuAST::Postcircumfix::ArrayIndex'
            && $postfix.index.^can('statements') && !$postfix.index.statements.elems
            && (!$postfix.colonpairs.defined || !$postfix.colonpairs.elems)
            && $source.operand.^name eq any(<RakuAST::Var::Lexical RakuAST::Var::Dynamic>)
            && $source.operand.name.starts-with('@');
        $source = $source.operand;
    }
    self.unsupported($variable) unless $source.^name eq any(<
        RakuAST::Var::Lexical RakuAST::Var::Dynamic>)
        && $source.name.substr(0, 1) eq any(<$ @>);
    # An inlined rule's closure can belong to another lexical frame. Never read
    # a same-named variable from the query caller in place of that closure.
    X::Red::Compiler::Unsupported.new(:fatal,
        :reason('Interpolated data inside inlined regex rules is not supported')).throw
        if %!active-rules.elems;
    my $index = @!literal-parameters.elems;
    @!literal-parameters.push: $source;
    ['literal-slot', $index,
        !$quoted && $source.name.starts-with('@') ?? 'alternatives' !! 'string']
}
