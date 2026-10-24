use nqp;
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
sub template(Bool $operators, @plan, Bool :$captures = False) {
    sub has-effects(@part) {
        return True if @part[0] eq any(<assign delete topic-assign let>);
        return False if @part[0] eq any(<literal capture local>);
        return so @part.skip(1).grep({ has-effects($_[1]) }) if @part[0] eq 'hash';
        so @part.skip(1).grep({ $_ ~~ Array && has-effects($_) })
    }
    Red::Compiler::Template.new(:$operators, :@plan,
        :builder(Red::Compiler::Emitter.build(@plan)),
        :validator(Red::Compiler::Emitter.validator(@plan)),
        :prevalidate(so ($captures || has-effects(@plan))))
}

class Translation {
    has %.parameters;
    has @.captures;
    has %!capture-index;
    has Bool $.predicate = False;
    has Bool $.updating = False;
    has %!locals;
    has Int $!next-local = 0;

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
                || $name.starts-with('RakuAST::VarDeclaration::');
            if $name eq 'RakuAST::Var::Lexical' {
                my $variable = $part.name;
                $independent = False if $variable eq '$_'
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
    method method-call($method, @receiver) {
        self.unsupported('Special method dispatch')
            if $method.dispatch.chars || !$method.name.is-identifier;
        self.unsupported('Method adverbs') if $method.colonpairs.DEFINITE
            && $method.colonpairs.elems;
        my $name = $method.name.canonicalize;
        my @args = $method.args.args;
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
                self.unsupported('Statement modifiers use symbolic evaluation')
                    if $value.condition-modifier.DEFINITE || $value.loop-modifier.DEFINITE;
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
            when 'RakuAST::Var::Lexical' | 'RakuAST::Var::Dynamic' {
                my $variable = $value.name;
                return ['local', %!locals{$variable}] if %!locals{$variable}:exists;
                return %!parameters{$variable} if %!parameters{$variable}:exists;
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
                return ['op', %operators{$operator}, self.expression($value.left),
                    self.expression($value.right), |@comparison];
            }
            when 'RakuAST::ApplyPrefix' {
                self.operator($value.prefix);
                my $operator = $value.prefix.operator;
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
                return ['case', self.expression($value.condition),
                    self.expression($value.then), self.expression($value.else)];
            }
            when 'RakuAST::Statement::If' {
                self.unsupported unless $value.else.DEFINITE && !$value.elsifs.elems;
                return ['case', self.expression($value.condition),
                    self.block($value.then), self.block($value.else)];
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
                self.unsupported('A function call depends on the query element')
                    unless self.independent($value);
                return self.capture($value, 'expression:' ~ $value.WHICH);
            }
            default { self.unsupported("Unsupported RakuAST node: $name") }
        }
    }
    method translate($block) {
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
sub red-compile($cu = $*CU, :&report) is export {
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
        my $reason = '';
        try {
            @plan = $translation.translate(@args[0]);
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
                    $reason = .reason;
                }
            }
        }
        report(:method($call.name.canonicalize), :source(@args[0].DEPARSE),
            :status($unsupported ?? 'unsupported' !! 'compiled'), :$reason)
            if &report.DEFINITE;
        @candidates.push: [$current, @plan.Array, $translation.captures.Array, @nested.Array]
            unless $unsupported;
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
        my $prototype = template($operators, @plan.Array, :captures(so @getters));
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
