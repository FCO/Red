use nqp;
use Red::Compiler::Regex;
use Red::Compiler::Template;
use Red::Compiler::Emitter;
use Red::Compiler::Runtime;
use X::Red::Exceptions;

#| Optional CHECK-time translation of query callbacks. No RakuAST types are
#| resolved while loading this module on the legacy frontend.
unit module Red::Compiler::RakuAST;

sub node(Str $name, |args) { ::('RakuAST::' ~ $name).new(|args) }
sub literal($value) { ::('RakuAST::Literal').from-value($value) }
sub invocation(&code, @arguments) {
    node('ApplyPostfix', :operand(literal(&code)),
        :postfix(node('Call::Term', :args(node('ArgList', |@arguments)))))
}
sub runtime-target($receiver) { Red::Compiler::Runtime.new(:$receiver) }
sub attach-getters($template, *@getters) { $template.clone(:@getters) }
sub template(Bool $operators, @plan, Bool :$captures = False, Bool :$warn,
    Str :$query-method = '', Str :$source = '', Bool :$regex-query = False,
    Code :$expected-callback) {
    sub has-effects(@part) {
        return True if @part[0] eq any(<assign delete topic-assign let>);
        return False if @part[0] eq any(<literal capture local>);
        return so @part.skip(1).grep({ has-effects($_[1]) }) if @part[0] eq 'hash';
        so @part.skip(1).grep({ $_ ~~ Array && has-effects($_) })
    }
    Red::Compiler::Template.new(:$operators, :@plan, :$warn, :$query-method, :$source, :$regex-query,
        :$expected-callback,
        :builder(Red::Compiler::Emitter.build(@plan)),
        :validator(Red::Compiler::Emitter.validator(@plan)),
        :prevalidate(so ($captures || has-effects(@plan))))
}

sub regex-declaration($value) {
    return Any unless $value.^name eq 'RakuAST::Var::Lexical' && $value.is-resolved;
    my $declaration = $value.resolution;
    $declaration.^name eq any(<RakuAST::RegexDeclaration RakuAST::TokenDeclaration
        RakuAST::RuleDeclaration>) ?? $declaration !! Any
}

class Translation {
    has %.parameters;
    has @.captures;
    has %!capture-index;
    has Bool $.predicate = False;
    has Bool $.updating = False;
    has %!locals;
    has @!regex-context;
    has Bool $!text-captures = False;
    has Bool $!presence-captures = False;
    has Int $!next-local = 0;
    has Code $.expected-callback;
    has %!active-inline;

    method unsupported(Str $reason = "Unsupported callback syntax") {
        X::Red::Compiler::Unsupported.new(:$reason).throw
    }
    method parameter($parameter) {
        self.unsupported if $parameter.type.DEFINITE || $parameter.optional
            || $parameter.slurpy.DEFINITE || $parameter.default.DEFINITE
            || $parameter.where.DEFINITE || $parameter.signature-constraint.DEFINITE
            || $parameter.names.elems;
    }
    method operator($operator) {
        self.unsupported('Metaoperators and mutations use symbolic evaluation')
            unless $operator.^name eq any(<RakuAST::Infix RakuAST::Prefix RakuAST::Postfix>);
        self.unsupported('Unresolved operator') unless $operator.is-resolved;
        my $code = $operator.resolution.compile-time-value;
        my @candidates = $code.^can("candidates") ?? $code.candidates !! ($code,);
        self.unsupported unless @candidates.map({
            .file.starts-with("SETTING::")
                || .file.ends-with("/Red/Operators.rakumod (Red::Operators)")
        }).all;
        $code
    }
    method type($value, Str $name --> Bool:D) { $value.^name eq 'RakuAST::' ~ $name }
    method children($value) {
        my @children;
        $value.visit-children(-> $child { @children.push: $child });
        @children
    }
    method statements($value) {
        my @statements = $value.statements;
        self.unsupported('Multiple statements use symbolic evaluation')
            unless @statements.elems == 1;
        @statements[0]
    }
    method block($value) {
        my %outer-locals = %!locals;
        LEAVE %!locals = %outer-locals;
        my @statements = $value.body.statement-list.statements;
        self.unsupported('Empty callback') unless @statements;
        return self.expression(@statements[0]) if @statements.elems == 1;
        ['sequence', |@statements.map({ self.expression($_) })]
    }
    method assignment(@target, @value) {
        self.unsupported('Updates are only compiled for map') unless $!updating;
        return ['let', @target[1], @value.Array] if @target[0] eq 'local';
        return ['topic-assign', @value.Array] if @target[0] eq 'subject';
        self.unsupported('Assignment target is not a column or JSON path')
            unless @target[0] eq any(<field index lookup>);
        ['assign', @target.Array, @value.Array]
    }
    method capture($value, Str $key) {
        return ['capture', %!capture-index{$key}] if %!capture-index{$key}:exists;
        my $index = @!captures.elems;
        %!capture-index{$key} = $index;
        @!captures.push: $value;
        ['capture', $index]
    }
    method interpolation($value) {
        if self.type($value, 'Block') {
            self.unsupported('Block phasers or parameters')
                if $value.has-any-phasers || $value.has-placeholder-parameters;
            return self.block($value);
        }
        self.expression($value)
    }
    method independent($value --> Bool:D) {
        my $independent = True;
        $value.visit(-> $part {
            my $name = $part.^name;
            $independent = False if $name eq any(<RakuAST::Term::TopicCall
                RakuAST::Term::Whatever RakuAST::WhateverCode::Argument>)
                || $name.starts-with('RakuAST::VarDeclaration::')
                || $name eq any(<RakuAST::Var::PositionalCapture RakuAST::Var::NamedCapture>);
            if $name eq 'RakuAST::Var::Lexical' {
                my $variable = $part.name;
                $independent = False if $variable eq any('$_', '$/')
                    || (%!parameters{$variable}:exists) || (%!locals{$variable}:exists);
            }
            True
        });
        $independent
    }
    method parameters($signature, @path = ['subject']) {
        my @parameters = $signature.parameters;
        self.unsupported unless @parameters.elems == 1 || @path[0] eq 'index';
        for @parameters.kv -> $i, $parameter {
            self.parameter($parameter);
            my @position = @path[0] eq 'index' ?? ['index', @path[1], $i] !! @path;
            if $parameter.sub-signature.DEFINITE {
                my @nested = $parameter.sub-signature.parameters;
                for @nested.kv -> $j, $nested {
                    self.parameter($nested);
                    self.unsupported unless $nested.target.^can('name')
                        && !$nested.sub-signature.DEFINITE;
                    %!parameters{$nested.target.name} = ['index', @position.Array, $j];
                }
            } else {
                self.unsupported unless $parameter.target.^can('name');
                %!parameters{$parameter.target.name} = @position.Array;
            }
        }
    }
    method closed-callable($callable) {
        self.unsupported('Callable traits and phasers use symbolic evaluation')
            if $callable.has-any-phasers || ($callable.?traits // ()).elems;
        my %allowed;
        %allowed<$_> = True if $callable.^name eq 'RakuAST::Block';
        my $signature = $callable.^name eq 'RakuAST::Block'
            ?? ($callable.has-placeholder-parameters ?? $callable.placeholder-signature !! Any)
            !! $callable.signature;
        if $signature.DEFINITE {
            for $signature.parameters -> $parameter {
                self.unsupported('Destructured callable parameters use symbolic evaluation')
                    unless $parameter.target.^can('name') && !$parameter.sub-signature.DEFINITE;
                %allowed{$parameter.target.name} = True;
            }
        }
        $callable.body.visit(-> $part {
            if $part.^name eq 'RakuAST::VarDeclaration::Simple' {
                %allowed{$part.sigil ~ $part.desigilname.canonicalize} = True;
            }
            True
        });
        $callable.body.visit(-> $part {
            my $name = $part.^name;
            self.unsupported('Nested callable declarations use symbolic evaluation')
                if $name eq any(<RakuAST::Block RakuAST::PointyBlock RakuAST::Sub>);
            self.unsupported('Implicit helper topics use symbolic evaluation')
                if $name eq 'RakuAST::Term::TopicCall'
                    && ($callable.^name eq 'RakuAST::Sub' || !(%allowed<$_>:exists));
            self.unsupported('Captured callable closure variables use symbolic evaluation')
                if $name eq any(<RakuAST::Var::Lexical RakuAST::Var::Dynamic>)
                    && !(%allowed{$part.name}:exists);
            True
        });
    }
    method inline-call($declaration, @arguments, $reference) {
        my Bool $entered = False;
        self.unsupported('Only plain lexical subroutines can be inlined')
            unless $declaration.^name eq 'RakuAST::Sub' && $declaration.scope eq 'my'
                && !$declaration.multiness.chars && !$declaration.signature.returns.DEFINITE;
        my $key = $declaration.WHERE.Str;
        self.unsupported('Recursive or deeply nested helpers use symbolic evaluation')
            if (%!active-inline{$key}:exists) || %!active-inline.elems >= 16;
        %!active-inline{$key} = True;
        my %previous-parameters = %!parameters;
        my %previous-locals = %!locals;
        my @previous-match = @!regex-context;
        $entered = True;
        LEAVE {
            if $entered {
                %!active-inline{$key}:delete;
                %!parameters = %previous-parameters;
                %!locals = %previous-locals;
                @!regex-context = @previous-match;
            }
        }
        self.closed-callable($declaration);
        my @parameters = $declaration.signature.parameters;
        self.unsupported('Helper argument arity does not match its signature')
            unless @parameters.elems == @arguments.elems;
        %!parameters = ();
        %!locals = ();
        @!regex-context = ();
        for @parameters.kv -> $index, $parameter {
            self.unsupported('Only unconstrained positional helper parameters are compiled')
                unless (!$parameter.type.DEFINITE
                    || ($parameter.type.^name eq 'RakuAST::Type::Setting'
                        && $parameter.type.name.canonicalize eq 'Any'))
                    && !$parameter.optional && !$parameter.slurpy.DEFINITE
                    && !$parameter.default.DEFINITE && !$parameter.where.DEFINITE
                    && !$parameter.signature-constraint.DEFINITE && !$parameter.names.elems
                    && !$parameter.traits.elems;
            %!parameters{$parameter.target.name} = @arguments[$index];
        }
        my $guard = self.capture($reference, 'helper:' ~ $key);
        my @body = self.block($declaration).list;
        sub check-pure(@plan, Bool :$argument = False) {
            return if @plan[0] eq any(<literal capture local>);
            self.unsupported('Helper mutations use symbolic evaluation')
                if @plan[0] eq any(<assign delete topic-assign>)
                    || ($argument && @plan[0] eq 'let');
            if @plan[0] eq 'hash' {
                check-pure($_[1], :$argument) for @plan.skip(1);
            } else {
                check-pure($_, :$argument) for @plan.skip(1).grep(* ~~ Array);
            }
        }
        check-pure($_, :argument) for @arguments;
        check-pure(@body);
        ['inline-call', $guard[1], $declaration.compile-time-value,
            ['list', |@arguments], @body.Array]
    }
    method named-callback($variable) {
        return Any unless $variable.^name eq 'RakuAST::Var::Lexical' && $variable.is-resolved;
        my $declaration = $variable.resolution;
        if $declaration.^name eq 'RakuAST::Sub' {
            return self.inline-call($declaration, [['subject'],], $variable);
        }
        return Any unless $declaration.^name eq 'RakuAST::VarDeclaration::Simple'
            && $declaration.scope eq 'my' && !$declaration.traits.elems
            && $declaration.initializer.^name eq 'RakuAST::Initializer::Assign';
        my $body = $declaration.initializer.expression;
        return Any unless $body.^name eq any(<RakuAST::Block RakuAST::PointyBlock>);
        self.closed-callable($body);
        $!expected-callback = $body.compile-time-value;
        self.translate($body)
    }
    method matcher-value($variable) {
        return self.expression($variable) unless $variable.name.starts-with('&')
            && !(%!parameters{$variable.name}:exists);
        self.capture($variable, 'regex-matcher:' ~ $variable.name)
    }
    method regex-plan(@subject, $quoted) {
        X::Red::Compiler::Unsupported.new(:fatal,
            :reason('SQL regex Match values are only compiled in predicates')).throw
            unless $!predicate;
        my $compiler = Red::Compiler::Regex.new;
        my $pattern = $compiler.compile($quoted);
        my @parameters = $compiler.literal-parameters.map({ self.expression($_) });
        @!regex-context = ();
        ['regex', @subject.Array, $pattern, |@parameters]
    }
    method capture-expression($value, Bool :$text = False, Bool :$presence = False) {
        my $previous = $!text-captures;
        my $previous-presence = $!presence-captures;
        LEAVE {
            $!text-captures = $previous;
            $!presence-captures = $previous-presence;
        }
        $!text-captures = $text;
        $!presence-captures = $presence;
        self.expression($value)
    }
    method capture-adverbs($value) {
        # PositionalCapture has no public colonpairs accessor on current Rakudo.
        my $slot = $value.^attributes.first(*.name eq '$!colonpairs');
        self.unsupported('RakuAST capture adverb metadata is unavailable') unless $slot.DEFINITE;
        my @pairs = $slot.get_value($value).list;
        return False unless @pairs;
        self.unsupported('Only Boolean :exists capture lookups are compiled')
            unless @pairs.elems == 1 && @pairs[0].^name eq 'RakuAST::ColonPair::True'
                && @pairs[0].key eq 'exists' && !$!text-captures;
        True
    }
    method capture-presence(@value) {
        self.unsupported('Presence checks require a scalar capture') unless @value[0] eq 'regex-value';
        return @value[1].Array if @value[2] ~~ Str && @value[2] eq '$/';
        ['regex-defined', @value.Array]
    }
    method match-read($selection, Bool :$presence = False) {
        X::Red::Compiler::Unsupported.new(:fatal, :reason(
            'Capture reads require text comparison, string coercion or an explicit presence check'
        )).throw unless $!text-captures || $presence || $!presence-captures;
        X::Red::Compiler::Unsupported.new(:fatal, :reason(
            'Regex capture reads require an unambiguous regex match source'
        )).throw unless @!regex-context;
        my @value = 'regex-value', @!regex-context.Array, $selection;
        $presence || $!presence-captures ?? self.capture-presence(@value) !! @value.Array
    }
    method has-new-match(@plan --> Bool:D) {
        return True if @plan[0] eq any(<regex regex-guard>);
        return False if @plan[0] eq any(<literal capture local regex-value regex-defined>);
        return so @plan.skip(1).grep({ self.has-new-match($_[1]) }) if @plan[0] eq 'hash';
        so @plan.skip(1).grep({ $_ ~~ Array && self.has-new-match($_) })
    }
    method merge-match-sources(@left, @right --> Array:D) {
        my %seen;
        (|@left, |@right).grep({ !%seen{.raku}++ }).Array
    }
    method match-sources(@plan, Bool:D $truth, @initial --> Array:D) {
        return [] unless @initial;
        return [@plan.Array,] if @plan[0] eq 'regex';
        if @plan[0] eq any(<not so>) {
            return self.match-sources(@plan[1], @plan[0] eq 'not' ?? !$truth !! $truth, @initial);
        }
        if @plan[0] eq 'literal' && @plan[1] ~~ Bool:D {
            return @plan[1] == $truth ?? @initial.Array !! [];
        }
        if @plan[0] eq 'op' && @plan[1] eq any(<AND OR>) {
            my @yes = self.match-sources(@plan[2], True, @initial).list;
            my @no = self.match-sources(@plan[2], False, @initial).list;
            return $truth
                ?? self.match-sources(@plan[3], True, @yes)
                !! self.merge-match-sources(@no, self.match-sources(@plan[3], False, @yes))
                if @plan[1] eq 'AND';
            return $truth
                ?? self.merge-match-sources(@yes, self.match-sources(@plan[3], True, @no))
                !! self.match-sources(@plan[3], False, @no);
        }
        if @plan[0] eq 'case' {
            my @yes = self.match-sources(@plan[1], True, @initial).list;
            my @no = self.match-sources(@plan[1], False, @initial).list;
            return self.merge-match-sources(
                self.match-sources(@plan[2], $truth, @yes),
                self.match-sources(@plan[3], $truth, @no));
        }
        self.has-new-match(@plan) ?? [[],] !! @initial.Array
    }
    method match-context(@condition, &body, Bool :$truth = True, :@prior = @!regex-context) {
        my @previous = @!regex-context;
        my @initial = @prior;
        LEAVE @!regex-context = @previous;
        my @sources = self.match-sources(@condition, $truth, [@initial.Array,]).list;
        @!regex-context = @sources.elems == 1 ?? @sources[0].list !! ();
        body()
    }
    method method-call($method, @receiver) {
        self.unsupported('Special method dispatch')
            if $method.dispatch.chars || !$method.name.is-identifier;
        self.unsupported('Method adverbs') if $method.colonpairs.DEFINITE
            && $method.colonpairs.elems;
        my $name = $method.name.canonicalize;
        my @args = $method.args.args;
        if $name eq 'chars' && !@args
            && (@receiver[0] eq 'regex-value'
                || (@receiver[0] eq 'call' && @receiver[1] eq 'Str'
                    && @receiver[2][0] eq 'regex-value')) {
            return ['regex-chars', @receiver.Array];
        }
        if @receiver[0] eq 'regex-value' {
            return ['call', 'Str', @receiver.Array] if $name eq 'Str' && !@args;
            return self.capture-presence(@receiver)
                if $name eq any(<defined Bool>) && !@args && !$!text-captures;
            X::Red::Compiler::Unsupported.new(:fatal, :reason(
                'Match object methods are not available on compiled capture text'
            )).throw;
        }
        if $name eq 'match' {
            self.unsupported('Only single Boolean regex matches are compiled') unless @args.elems == 1;
            return self.regex-plan(@receiver, @args[0]);
        }
        my %arity = defined => [0], contains => [1], elems => [0],
            starts-with => [1], ends-with => [1], substr => [1, 2], index => [1],
            lc => [0], uc => [0], cast => [1];
        if %arity{$name}:exists {
            self.unsupported('Unsupported method arguments')
                unless @args.elems == any(%arity{$name}.list);
            return ['call', $name, @receiver.Array, |@args.map({ self.expression($_) })];
        }
        self.unsupported if @args.elems || @receiver[0] ne any(<subject field index>);
        ['field', @receiver.Array, $name]
    }
    method postfix($postfix, @receiver) {
        if self.type($postfix, 'Postfix') && $postfix.operator eq any(<++ -->) {
            self.operator($postfix);
            my @update = self.assignment(@receiver, ['op',
                $postfix.operator eq '++' ?? 'Sum' !! 'Sub', @receiver.Array, ['literal', 1]]);
            my $old-value = $!next-local++;
            return ['sequence', ['let', $old-value, @receiver.Array],
                @update.Array, ['local', $old-value]];
        }
        return self.method-call($postfix, @receiver) if self.type($postfix, 'Call::Method');
        if $postfix.^name eq any(<
            RakuAST::Postcircumfix::ArrayIndex RakuAST::Postcircumfix::HashIndex
            RakuAST::Postcircumfix::LiteralHashIndex
        >) {
            my $assignee = $postfix.^can('assignee') ?? $postfix.assignee !! Any;
            my @adverbs = $postfix.colonpairs.DEFINITE ?? $postfix.colonpairs.list !! ();
            my $existence = False;
            my $deletion = False;
            my $negated = False;
            if @adverbs {
                self.unsupported('Unsupported index adverb (including deletion)')
                    unless @adverbs.elems == 1 && @adverbs[0].key eq any(<exists delete>)
                        && @adverbs[0].^name eq any(<
                            RakuAST::ColonPair::True RakuAST::ColonPair::False>);
                $deletion = @adverbs[0].key eq 'delete'
                    && @adverbs[0].^name eq 'RakuAST::ColonPair::True';
                self.unsupported('Deletion is only compiled for map') if $deletion && !$!updating;
                $existence = @adverbs[0].key eq 'exists';
                $negated = $existence && @adverbs[0].^name eq 'RakuAST::ColonPair::False';
            }
            my $index = $postfix.index;
            $index = self.statements($index) if $index.^can('statements');
            my @key = self.expression($index);
            if self.type($postfix, 'Postcircumfix::LiteralHashIndex') && @key[0] eq 'list' {
                self.unsupported('Index slices use symbolic evaluation') unless @key.elems == 2;
                @key = @key[1].list;
            }
            self.unsupported('Index slices use symbolic evaluation')
                if @key[0] eq any(<array list>);
            my @result = @key[0] eq 'literal' && @key[1] ~~ Str | Int && !$existence
                ?? ['index', @receiver.Array, @key[1]]
                !! [$existence ?? 'exists' !! 'lookup', @receiver.Array, @key.Array];
            return self.assignment(@result, self.expression($assignee)) if $assignee.DEFINITE;
            return ['delete', @receiver.Array, @key.Array] if $deletion;
            return $negated ?? ['not', @result.Array] !! @result.Array;
        }
        self.unsupported
    }
    method expression($value) {
        my $name = $value.^name;
        given $name {
            when 'RakuAST::Statement::Expression' {
                self.unsupported('Loop modifiers use symbolic evaluation')
                    if $value.loop-modifier.DEFINITE;
                if $value.condition-modifier.DEFINITE {
                    my $modifier = $value.condition-modifier;
                    self.unsupported('Only predicate if/unless modifiers are compiled')
                        unless $!predicate && $modifier.^name eq any(<
                            RakuAST::StatementModifier::If RakuAST::StatementModifier::Unless>);
                    my @children = self.children($modifier);
                    self.unsupported unless @children.elems == 1;
                    my @prior = @!regex-context;
                    my @condition = self.expression(@children[0]);
                    my @body = self.match-context(@condition, -> {
                        ['so', self.expression($value.expression)]
                    }, :prior(@prior),
                        :truth($modifier.^name eq 'RakuAST::StatementModifier::If')).list;
                    @condition = ['not', @condition.Array]
                        if $modifier.^name eq 'RakuAST::StatementModifier::Unless';
                    return ['case', @condition.Array, @body.Array, ['literal', False]];
                }
                return self.expression($value.expression);
            }
            when 'RakuAST::IntLiteral' | 'RakuAST::NumLiteral' | 'RakuAST::RatLiteral'
                | 'RakuAST::StrLiteral' {
                return ['literal', $value.compile-time-value];
            }
            when 'RakuAST::VarDeclaration::Simple' {
                self.unsupported('Only untyped scalar local initializers are compiled')
                    unless $value.scope eq 'my' && !$value.traits.elems
                        && $value.sigil eq '$' && !$value.twigil.chars
                        && !$value.type.DEFINITE
                        && $value.initializer.^name eq 'RakuAST::Initializer::Assign';
                my @initial = self.expression($value.initializer.expression);
                my $variable = '$' ~ $value.desigilname.canonicalize;
                self.unsupported('Local variable shadows a callback parameter')
                    if %!parameters{$variable}:exists;
                my $id = $!next-local++;
                %!locals{$variable} = $id;
                return ['let', $id, @initial.Array];
            }
            when 'RakuAST::VarDeclaration::Placeholder::Positional' {
                my $variable = $value.lexical-name;
                self.unsupported('Unbound placeholder') unless %!parameters{$variable}:exists;
                return %!parameters{$variable};
            }
            when 'RakuAST::Block' {
                self.unsupported('Block values use symbolic evaluation');
            }
            when 'RakuAST::StatementPrefix::Do' {
                return self.interpolation($value.blorst);
            }
            when 'RakuAST::Var::PositionalCapture' {
                self.unsupported('Only scalar positional capture reads are compiled')
                    unless $value.sigil eq '$';
                my $presence = self.capture-adverbs($value);
                return self.match-read($value.index, :$presence);
            }
            when 'RakuAST::Var::NamedCapture' {
                my $presence = self.capture-adverbs($value);
                my $key = $value.index;
                self.unsupported('Only scalar literal named capture reads are compiled')
                    unless $value.sigil eq '$' && $key.^name eq 'RakuAST::QuotedString'
                        && $key.segments.map(*.^name).all eq 'RakuAST::StrLiteral';
                my $name = $key.segments.map(*.compile-time-value).join;
                self.unsupported('Only one literal named capture is supported')
                    unless $name.words.elems == 1;
                return self.match-read($name, :$presence);
            }
            when 'RakuAST::Var::Lexical' | 'RakuAST::Var::Dynamic' {
                my $variable = $value.name;
                return ['local', %!locals{$variable}] if %!locals{$variable}:exists;
                return %!parameters{$variable} if %!parameters{$variable}:exists;
                return self.match-read('$/') if $variable eq '$/';
                return ['subject'] if $variable eq '$_';
                self.unsupported unless $variable.substr(0, 1) eq any(<$ @ %>);
                return self.capture($value, $variable);
            }
            when 'RakuAST::Term::Whatever' { return ['subject'] }
            when 'RakuAST::WhateverCode::Argument' {
                self.unsupported('HyperWhatever is not a scalar parameter') if $value.is-hyper;
                return ['subject'];
            }
            when 'RakuAST::Term::TopicCall' {
                return self.postfix(self.children($value)[0], ['subject']);
            }
            when 'RakuAST::ApplyPostfix' {
                my $postfix = $value.postfix;
                if $postfix.^name eq 'RakuAST::Call::Method'
                    && $postfix.name.is-identifier
                    && $postfix.name.canonicalize eq any(<Str defined Bool chars>)
                    && !$postfix.args.args.elems
                    && ($value.operand.^name eq any(<RakuAST::Var::PositionalCapture
                        RakuAST::Var::NamedCapture>)
                        || ($value.operand.^name eq 'RakuAST::Var::Lexical'
                            && $value.operand.name eq '$/')) {
                    return ['regex-chars', self.capture-expression($value.operand, :text)]
                        if $postfix.name.canonicalize eq 'chars';
                    return ['call', 'Str', self.capture-expression($value.operand, :text)]
                        if $postfix.name.canonicalize eq 'Str';
                    self.unsupported('Capture presence checks require a Boolean context')
                        if $!text-captures;
                    self.unsupported('Presence methods cannot chain capture lookup adverbs')
                        if $value.operand.^name ne 'RakuAST::Var::Lexical'
                            && self.capture-adverbs($value.operand);
                    return self.capture-expression($value.operand, :presence);
                }
                if self.independent($value) {
                    return self.capture($value, 'expression:' ~ $value.WHICH);
                }
                return self.postfix($value.postfix, self.expression($value.operand));
            }
            when 'RakuAST::ApplyListInfix' {
                self.unsupported('Unsupported list operator') unless $value.infix.operator eq ',';
                self.operator($value.infix);
                return ['list', |$value.operands.map({ self.expression($_) })];
            }
            when 'RakuAST::ApplyInfix' {
                if self.type($value.infix, 'MetaInfix::Assign') {
                    my $operator = $value.infix.infix;
                    self.operator($operator);
                    my %operations = '+' => 'Sum', '-' => 'Sub', '*' => 'Mul',
                        '/' => 'Div', '%' => 'Mod', '~' => 'Concat';
                    self.unsupported('Unsupported compound assignment')
                        unless %operations{$operator.operator}:exists;
                    my @target = self.expression($value.left);
                    return self.assignment(@target,
                        ['op', %operations{$operator.operator}, @target.Array,
                            self.expression($value.right)]);
                }
                if self.type($value.infix, 'Infix') && $value.infix.operator eq '=' {
                    return self.assignment(self.expression($value.left), self.expression($value.right));
                }
                if self.type($value.infix, 'Infix') && $value.infix.operator eq '~~' {
                    self.operator($value.infix);
                    return self.regex-plan(self.expression($value.left), $value.right)
                        if self.type($value.right, 'QuotedRegex');
                    my $declaration = regex-declaration($value.right);
                    return self.regex-plan(self.expression($value.left), $declaration)
                        if $declaration.DEFINITE;
                    if $value.right.^name eq any(<RakuAST::Var::Lexical RakuAST::Var::Dynamic>) {
                        return ['regex-guard', self.matcher-value($value.right)];
                    }
                    self.unsupported('Non-regex smartmatches use symbolic evaluation');
                }
                my %operators = '+' => 'Sum', '-' => 'Sub', '*' => 'Mul', '/' => 'Div',
                    '%' => 'Mod', 'div' => 'IDiv', '%%' => 'Divisible', '~' => 'Concat', '==' => 'Eq', '!=' => 'Ne',
                    '<' => 'Lt', '<=' => 'Le', '>' => 'Gt', '>=' => 'Ge',
                    'eq' => 'Eq', 'ne' => 'Ne', 'lt' => 'Lt', 'le' => 'Le',
                    'gt' => 'Gt', 'ge' => 'Ge',
                    'in' => 'In', '⊂' => 'In', '(<)' => 'In',
                    '⊃' => 'NotIn', '(>)' => 'NotIn';
                %operators<&&> = 'AND' if $!predicate;
                %operators<||> = 'OR' if $!predicate;
                my &implementation = self.operator($value.infix);
                my $operator = $value.infix.operator;
                self.unsupported unless %operators{$operator}:exists;
                my @comparison = $operator eq any('==', '!=', '<', '<=', '>', '>=',
                    'eq', 'ne', 'lt', 'le', 'gt', 'ge')
                    ?? [$operator, &implementation] !! [];
                if $operator eq any(<&& ||>) {
                    my @prior = @!regex-context;
                    my @left = self.capture-expression($value.left).list;
                    my @right = self.match-context(@left, -> {
                        self.capture-expression($value.right)
                    }, :prior(@prior), :truth($operator eq '&&')).list;
                    my @plan = 'op', %operators{$operator}, @left.Array, @right.Array;
                    @!regex-context = () if self.has-new-match(@plan);
                    return @plan.Array;
                }
                my Bool $text = so $operator eq any(<eq ne lt le gt ge ~>);
                return ['op', %operators{$operator},
                    self.capture-expression($value.left, :$text),
                    self.capture-expression($value.right, :$text), |@comparison];
            }
            when 'RakuAST::ApplyPrefix' {
                self.operator($value.prefix);
                my $operator = $value.prefix.operator;
                if $operator eq any(<! not so>)
                    && ($value.operand.^name eq any(<RakuAST::Var::PositionalCapture
                        RakuAST::Var::NamedCapture>)
                        || ($value.operand.^name eq 'RakuAST::Var::Lexical'
                            && $value.operand.name eq '$/')) {
                    self.unsupported('Capture presence checks require a Boolean context')
                        if $!text-captures;
                    my @presence = self.capture-expression($value.operand, :presence).list;
                    return $operator eq 'so' ?? @presence.Array !! ['not', @presence.Array];
                }
                return ['call', 'Str', self.capture-expression($value.operand, :text)]
                    if $operator eq '~'
                    && ($value.operand.^name eq any(<RakuAST::Var::PositionalCapture
                        RakuAST::Var::NamedCapture>)
                        || ($value.operand.^name eq 'RakuAST::Var::Lexical'
                            && $value.operand.name eq '$/'));
                if $operator eq any(<++ -->) {
                    my @target = self.expression($value.operand);
                    return self.assignment(@target, ['op',
                        $operator eq '++' ?? 'Sum' !! 'Sub', @target.Array, ['literal', 1]]);
                }
                self.unsupported('Unsupported prefix operator')
                    unless $operator eq any(<- +>)
                        || ($operator eq any(<! not so>) && $!predicate);
                return self.expression($value.operand) if $operator eq '+';
                return ['so', self.expression($value.operand)] if $operator eq 'so';
                return [$operator eq '-' ?? 'negate' !! 'not',
                    self.expression($value.operand)];
            }
            when 'RakuAST::QuotedString' {
                my @segments = $value.segments;
                if @segments.map(*.^name).all eq 'RakuAST::StrLiteral' {
                    my $text = @segments.map(*.compile-time-value).join;
                    if $value.processors.grep(* eq 'words') {
                        self.unsupported('Unsupported word quoting processor')
                            if $value.processors.grep({ $_ ne any(<words val>) });
                        return ['list', |$text.words.map({
                            ['literal', $value.processors.grep(* eq 'val') ?? val($_) !! $_]
                        })];
                    }
                    self.unsupported('Unsupported string processor') if $value.processors.elems;
                    return ['literal', $text];
                }
                self.unsupported if $value.processors.elems;
                return ['string', |@segments.map({ self.interpolation($_) })];
            }
            when 'RakuAST::Circumfix::Parentheses' | 'RakuAST::Circumfix::ArrayComposer' {
                my $content = self.children($value)[0];
                my @statements = $content.statements;
                return [$name.ends-with('ArrayComposer') ?? 'array' !! 'list']
                    unless @statements;
                self.unsupported unless @statements.elems == 1;
                my $expression = @statements[0].expression;
                my @elements = self.type($expression, 'ApplyListInfix')
                    && $expression.infix.operator eq ',' ?? $expression.operands !! ($expression,);
                return self.expression($expression) if @elements.elems == 1
                    && $name.ends-with('Parentheses');
                return [$name.ends-with('ArrayComposer') ?? 'array' !! 'list',
                    |@elements.map({ self.expression($_) })];
            }
            when 'RakuAST::Contextualizer::Hash' | 'RakuAST::Circumfix::HashComposer' {
                my $expression;
                if self.type($value, 'Circumfix::HashComposer') {
                    self.unsupported('Object Hash projections') if $value.object-hash;
                    return ['hash'] unless $value.expression.DEFINITE;
                    $expression = $value.expression;
                } else {
                    my $content = self.children($value)[0];
                    my @statements = $content.statements;
                    return ['hash'] unless @statements;
                    self.unsupported('Hash with multiple statements') unless @statements.elems == 1;
                    $expression = @statements[0].expression;
                }
                my @pairs = self.type($expression, 'ApplyListInfix')
                    && $expression.infix.operator eq ',' ?? $expression.operands !! ($expression,);
                my @items = @pairs.map(-> $pair {
                    if self.type($pair, 'FatArrow') {
                        [$pair.key, self.expression($pair.value)]
                    } elsif $pair.^name eq any(<RakuAST::ColonPair::Value
                        RakuAST::ColonPair::Variable>) {
                        [$pair.key, self.expression($pair.value)]
                    } elsif $pair.^name eq any(<RakuAST::ColonPair::True
                        RakuAST::ColonPair::False RakuAST::ColonPair::Number>) {
                        [$pair.key, ['literal', $pair.simple-compile-time-quote-value]]
                    } else {
                        self.unsupported('Unsupported Hash member');
                    }
                });
                return ['hash', |@items];
            }
            when 'RakuAST::Ternary' {
                my @prior = @!regex-context;
                my @condition = self.capture-expression($value.condition);
                my @yes = self.match-context(@condition, -> { self.expression($value.then) }, :prior(@prior)).list;
                my @no = self.match-context(@condition, -> { self.expression($value.else) }, :prior(@prior), :!truth).list;
                return ['case', @condition.Array, @yes.Array, @no.Array];
            }
            when 'RakuAST::Statement::If' {
                self.unsupported unless !$value.elsifs.elems
                    && ($value.else.DEFINITE || $!predicate);
                my @prior = @!regex-context;
                my @condition = self.capture-expression($value.condition);
                my @yes = self.match-context(@condition, -> { self.block($value.then) }, :prior(@prior)).list;
                my @no = $value.else.DEFINITE
                    ?? self.match-context(@condition, -> { self.block($value.else) }, :prior(@prior), :!truth).list
                    !! ['literal', False];
                @yes = ['so', @yes.Array] unless $value.else.DEFINITE;
                return ['case', @condition.Array, @yes.Array, @no.Array];
            }
            when 'RakuAST::Term::Name' | 'RakuAST::Term::Enum' {
                my $term = $value.name.canonicalize;
                my %constants = True => True, False => False, Any => Any, Nil => Nil;
                self.unsupported unless %constants{$term}:exists;
                return ['literal', %constants{$term}];
            }
            when 'RakuAST::Call::Name' | 'RakuAST::Call::Name::WithoutParentheses'
                | 'RakuAST::Type::Simple' {
                self.unsupported('Control-flow functions use symbolic evaluation')
                    if $value.^can('name')
                        && $value.name.canonicalize eq any(<next last redo return take proceed succeed>);
                unless self.independent($value) {
                    self.unsupported('A function call depends on the query element')
                        unless $value.^can('is-resolved') && $value.is-resolved
                            && $value.resolution.^name eq 'RakuAST::Sub';
                    my @arguments = $value.args.args.map({ self.expression($_) });
                    my $reference = node('Var::Lexical', '&' ~ $value.name.canonicalize);
                    $reference.set-resolution($value.resolution);
                    return self.inline-call($value.resolution, @arguments, $reference);
                }
                return self.capture($value, 'expression:' ~ $value.WHICH);
            }
            default { self.unsupported("Unsupported RakuAST node: $name") }
        }
    }
    method translate($block) {
        return self.regex-plan(['subject'], $block) if self.type($block, 'QuotedRegex');
        my $declaration = regex-declaration($block);
        return self.regex-plan(['subject'], $declaration) if $declaration.DEFINITE;
        if $block.^name eq any(<RakuAST::Var::Lexical RakuAST::Var::Dynamic>) {
            my $named = self.named-callback($block);
            return $named.list if $named.DEFINITE;
            return ['regex-guard', self.matcher-value($block)];
        }
        if self.type($block, 'PointyBlock') {
            self.parameters($block.signature);
            return self.block($block);
        }
        if self.type($block, 'Block') {
            self.unsupported('Block phasers') if $block.has-any-phasers;
            self.parameters($block.placeholder-signature) if $block.has-placeholder-parameters;
            return self.block($block);
        }
        my $whatevers = 0;
        sub count($part) {
            $whatevers++ if $part.^name eq any(<RakuAST::Term::Whatever RakuAST::WhateverCode::Argument>);
            $part.visit-children(-> $child { count($child) });
        }
        count($block);
        self.unsupported unless $whatevers == 1 && !self.type($block, 'Term::Whatever');
        self.expression($block)
    }
}

#| Translate supported callbacks in the caller's current compilation unit.
sub red-compile($cu = $*CU, :&report, Bool :$warn) is export {
    X::Red::Projection.new(:reason(
        'red-compile requires the RakuAST frontend (RAKUDO_RAKUAST=1)'
    )).throw unless $cu.^name eq 'RakuAST::CompUnit';
    my $resolver = $cu.resolver.clone;
    my @candidates;
    sub discover($current, @scopes) {
        my @nested = @scopes;
        @nested.push: $current if $current ~~ ::('RakuAST::LexicalScope');
        $current.visit-children(-> $child { discover($child, @nested) });
        my $dotty = $current.^name eq 'RakuAST::ApplyDottyInfix'
            && $current.infix.^name eq 'RakuAST::DottyInfix::Call';
        return unless $dotty || $current.^name eq 'RakuAST::ApplyPostfix';
        my $call = $dotty ?? $current.right !! $current.postfix;
        return unless $call.^name eq 'RakuAST::Call::Method' && !$call.dispatch.chars
            && $call.name.is-identifier
            && $call.name.canonicalize eq any(<map grep first sort>);
        my @args = $call.args.args;
        return unless @args.elems && @args.skip(1).map({
            .^name eq any(<RakuAST::ColonPair::Value RakuAST::ColonPair::True
                RakuAST::ColonPair::False>)
        }).all;
        return if @args.skip(1).grep({ .key eq 'red-ast' }).elems;
        my $translation = Translation.new(
            :predicate(so $call.name.canonicalize eq any(<grep first>)),
            :updating($call.name.canonicalize eq 'map'));
        my @plan;
        my $unsupported = False;
        my $fatal = False;
        my $has-regex = False;
        @args[0].visit(-> $part {
            $has-regex = True if $part.^name eq any(<RakuAST::QuotedRegex
                RakuAST::Var::PositionalCapture RakuAST::Var::NamedCapture>)
                || ($part.^name eq 'RakuAST::Var::Lexical' && $part.name eq '$/')
                || regex-declaration($part).DEFINITE;
            True
        });
        my $reason = '';
        try {
            @plan = $translation.translate(@args[0]).list;
            sub check-effects(@part, Bool $conditional = False) {
                return if @part[0] eq any(<literal capture local>);
                if @part[0] eq 'hash' {
                    check-effects($_[1], $conditional) for @part.skip(1);
                    return;
                }
                $translation.unsupported('Conditional updates require conditional effect merging')
                    if $conditional && @part[0] eq any(<assign delete topic-assign let>);
                for @part.skip(1).grep(* ~~ Array) -> $child {
                    check-effects($child, $conditional || @part[0] eq 'case');
                }
            }
            check-effects(@plan);
            CATCH {
                when X::Red::Compiler::Unsupported {
                    $unsupported = True;
                    $fatal = .fatal || $has-regex;
                    $reason = .reason;
                }
            }
        }
        my $method = $call.name.canonicalize;
        my Bool $instrument = !$unsupported || $fatal || $warn.DEFINITE
            || compiler-warnings-enabled();
        my $source = $instrument || &report.DEFINITE
            ?? ((try @args[0].DEPARSE) // '<unknown callback>') !! '';
        report(:$method, :$source,
            :status($unsupported ?? 'unsupported' !! 'compiled'), :$reason)
            if &report.DEFINITE;
        if $instrument {
            @candidates.push: [$current, @plan.Array,
                ($unsupported ?? [] !! $translation.captures.Array), @nested.Array,
                $unsupported, $reason, $source, $method, $fatal, $has-regex,
                $translation.expected-callback];
        }
    }
    discover($cu, []);
    for @candidates -> $candidate {
        my $current = $candidate[0];
        my @plan = $candidate[1].list;
        my @captures = $candidate[2].list;
        my @scopes = $candidate[3].list;
        $resolver.push-scope($_) for @scopes;
        my $operators = so $resolver.resolve-lexical('&__RED_OPERATOR_LOADED__');
        my @getters = @captures.map(-> $capture {
            my $getter = node('Block', :implicit-topic(False), :body(node('Blockoid',
                node('StatementList', node('Statement::Expression', :expression($capture))))));
            $getter.IMPL-BEGIN($resolver, $cu.context);
            $getter.IMPL-CHECK($resolver, $cu.context);
            $getter
        });
        $resolver.pop-scope for @scopes;
        # Capture-free templates contain no closure state and can be shared across calls.
        my $prototype = $candidate[4]
            ?? Red::Compiler::Template.new(:$operators, :$warn,
                :unsupported-reason($candidate[5]), :fatal-unsupported($candidate[8]),
                :source($candidate[6]), :regex-query($candidate[9]),
                :query-method($candidate[7]))
            !! template($operators, @plan.Array, :captures(so @getters), :$warn,
                :source($candidate[6]), :query-method($candidate[7]), :regex-query($candidate[9]),
                :expected-callback($candidate[10]));
        my $factory = @getters
            ?? invocation(&attach-getters, [literal($prototype), |@getters])
            !! literal($prototype);
        if $current.^name eq 'RakuAST::ApplyDottyInfix' {
            $current.right.args.push(node('ColonPair::Value', :key<red-ast>, :value($factory)));
            nqp::bindattr(nqp::decont($current), nqp::decont(::('RakuAST::ApplyDottyInfix')), '$!left',
                invocation(&runtime-target, [$current.left]));
        } else {
            $current.postfix.args.push(node('ColonPair::Value', :key<red-ast>, :value($factory)));
            $current.set-operands(nqp::list(invocation(&runtime-target, [$current.operand])));
        }
    }
    Nil
}
