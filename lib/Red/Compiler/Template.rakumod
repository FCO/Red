use Red::AST;
use Red::AST::Value;
use Red::AST::Infixes;
use Red::AST::Unary;
use Red::AST::IsDefined;
use Red::AST::Case;
use Red::AST::JsonItem;
use Red::AST::JsonOperation;
use Red::AST::Divisible;
use Red::Projection;
use Red::Type::Json;
use X::Red::Exceptions;

unit class Red::Compiler::Template;

#| A query expression compiled independently of SQL aliases and closure instances.

has @.plan;
has @.getters;
has @.values;
has Bool $.bound = False;
has Bool $.operators = False;
has Bool $.prevalidate = True;
has &.builder;
has &.validator;

method unsupported(Str $reason) {
    X::Red::Compiler::Unsupported.new(:$reason).throw
}

method path(@plan, $subject) {
    given @plan[0] {
        when 'subject' {
            my $locals = try %*RED-COMPILER-LOCALS;
            $locals.DEFINITE && ($locals<topic>:exists) ?? $locals<topic> !! $subject
        }
        when 'field' {
            my $value = self.path(@plan[1], $subject);
            my $name = @plan[2];
            self.unsupported("Unknown model member: $name")
                unless $value ~~ ::('Red::Model') && !$value.DEFINITE
                    && ($value.^columns.grep({ .name.substr(2) eq $name }).elems
                        || $value.^relationships.keys.grep({ .name.substr(2) eq $name }).elems);
            $value."$name"()
        }
        when 'index' {
            my $value = self.path(@plan[1], $subject);
            my $key = @plan[2];
            if $value ~~ Red::AST && $value.returns ~~ Json {
                $value ~~ ::('Red::ColumnMethods')
                    ?? ($key ~~ Int ?? $value.AT-POS($key) !! $value.AT-KEY($key))
                    !! ($key ~~ Int ?? ($value but ::('Red::ColumnMethods')).AT-POS($key)
                        !! ($value but ::('Red::ColumnMethods')).AT-KEY($key))
            } elsif $value ~~ Associative {
                self.unsupported("Unknown projected key: $key") unless $value{$key}:exists;
                $value{$key}
            } elsif $value ~~ Positional && $key ~~ Int && 0 <= $key < $value.elems {
                $value[$key]
            } else {
                self.unsupported('The projected element does not support this index')
            }
        }
        default { self.unsupported('A model path must start at the block parameter') }
    }
}

method validate(@plan, $subject) {
    if @plan[0] eq 'topic-assign' {
        self.unsupported('Only scalar projection parameters can be reassigned')
            unless $subject ~~ Red::AST;
    }
    if @plan[0] eq 'assign' {
        my $target = @plan[1][0] eq any(<field index>)
            ?? self.path(@plan[1], $subject) !! Any;
        self.unsupported('A read-only column cannot be updated')
            if $target ~~ ::('Red::Column') && !$target.attr.rw;
    }
    return if @plan[0] eq 'local';
    return if @plan[0] eq any(<literal capture>);
    if @plan[0] eq 'hash' {
        self.validate($_[1], $subject) for @plan.skip(1);
        return;
    }
    return self.path(@plan, $subject) if @plan[0] eq any(<subject field index>);
    if @plan[0] eq any(<lookup exists>) {
        my $value = self.path(@plan[1], $subject);
        self.unsupported('Dynamic indexing and existence require a JSON expression')
            unless $value ~~ Red::AST && $value.returns ~~ Json;
        return self.validate(@plan[2], $subject);
    }
    for @plan.skip(1) -> $part {
        self.validate($part, $subject) if $part ~~ Array;
    }
}

#| Bind captures once; rebinding SQL aliases does not read the captures again.
method bind($subject --> Red::Compiler::Template:D) {
    my $*RED-INTERNAL = True;
    my %*RED-COMPILER-LOCALS;
    # Pure capture-free plans validate paths during evaluation. Captures and
    # mutations must still be checked before any getters or effects run.
    if $!prevalidate {
        &!validator.DEFINITE ?? &!validator(self, $subject) !! self.validate(@!plan, $subject);
    }
    return self unless @!getters;
    my @values = @!getters.map(-> &getter {
        my $value;
        {
            $value = getter();
            CONTROL {
                default { self.unsupported('Control flow in a captured expression') }
            }
        }
        $value.item
    });
    self.clone(:bound, :@values)
}

method evaluate(@plan, $subject) {
    given @plan[0] {
        when 'sequence' {
            my $result;
            $result = self.evaluate($_, $subject) for @plan.skip(1);
            $result
        }
        when 'topic-assign' {
            %*RED-COMPILER-LOCALS<topic> = self.evaluate(@plan[1], $subject)
        }
        when 'let' {
            %*RED-COMPILER-LOCALS{@plan[1]} = self.evaluate(@plan[2], $subject)
        }
        when 'local' { %*RED-COMPILER-LOCALS{@plan[1]} }
        when 'assign' {
            my @target = @plan[1].list;
            my $value = self.evaluate(@plan[2], $subject);
            if @target[0] eq 'field' {
                my $receiver = self.path(@target[1], $subject);
                $receiver."{@target[2]}"() = $value;
            } else {
                my $receiver = self.path(@target[1], $subject);
                my $key = @target[0] eq 'index'
                    ?? @target[2] !! self.evaluate(@target[2], $subject);
                if $key ~~ Int || ($key ~~ Red::AST && $key.returns ~~ Int) {
                    $receiver.AT-POS($key) = $value;
                } else {
                    $receiver.AT-KEY($key) = $value;
                }
            }
            $value
        }
        when 'delete' {
            my $receiver = self.path(@plan[1], $subject);
            my $key = self.evaluate(@plan[2], $subject);
            $receiver = $receiver but ::('Red::ColumnMethods')
                unless $receiver ~~ ::('Red::ColumnMethods');
            $key ~~ Int || ($key ~~ Red::AST && $key.returns ~~ Int)
                ?? $receiver.DELETE-POS($key) !! $receiver.DELETE-KEY($key)
        }
        when 'literal' { @plan[1] }
        when 'capture' { @!values[@plan[1]] }
        when 'subject' | 'field' | 'index' { self.path(@plan, $subject) }
        when 'lookup' | 'exists' {
            my $value = self.path(@plan[1], $subject);
            self.unsupported('Dynamic indexing and existence require a JSON expression')
                unless $value ~~ Red::AST && $value.returns ~~ Json;
            my $key = ast-value(self.evaluate(@plan[2], $subject));
            self.unsupported('A JSON index must be a string or integer expression')
                unless $key.returns ~~ Str | Int;
            my $item = Red::AST::JsonItem.new($value, $key);
            @plan[0] eq 'exists'
                ?? Red::AST::JsonOperation.new(:operation<exists>, :value($item))
                !! ($item but ::('Red::ColumnMethods'))
        }
        when 'array' { @plan.skip(1).map({ self.evaluate($_, $subject).item }).Array }
        when 'list' { @plan.skip(1).map({ self.evaluate($_, $subject).item }).List }
        when 'hash' {
            @plan.skip(1).map({ .[0] => self.evaluate(.[1], $subject) }).Hash
        }
        when 'string' {
            my @parts = @plan.skip(1).map({
                my $part = ast-value(self.evaluate($_, $subject));
                $part.returns ~~ Str ?? $part !! Red::AST::Cast.new($part, 'text')
            });
            my $result = @parts.shift // ast-value('');
            $result = Red::AST::Concat.new($result, $_) for @parts;
            $result
        }
        when 'op' {
            my $left = self.evaluate(@plan[2], $subject);
            my $right = self.evaluate(@plan[3], $subject);
            return @plan[5]($left, $right) if @plan[5] ~~ Callable;
            $left = ast-value($left);
            if @plan[1] eq any(<In NotIn>) {
                $right = $right.ast(:sub-select) if $right ~~ ::('Red::ResultSeq');
                $right = $right.as-sub-select if $right ~~ ::('Red::AST::Select');
            }
            $right = ast-value($right);
            ::('Red::AST::' ~ @plan[1]).new($left, $right)
        }
        when 'so' { Red::AST::So.new(ast-value(self.evaluate(@plan[1], $subject))) }
        when 'not' { Red::AST::Not.new(ast-value(self.evaluate(@plan[1], $subject))) }
        when 'negate' {
            Red::AST::Mul.new(ast-value(-1), ast-value(self.evaluate(@plan[1], $subject)))
        }
        when 'call' {
            my $value = self.evaluate(@plan[2], $subject);
            my @args = @plan.skip(3).map({ self.evaluate($_, $subject) });
            $value = $value but ::('Red::ColumnMethods')
                if $value ~~ Red::AST && $value !~~ ::('Red::ColumnMethods');
            $value."{@plan[1]}"(|@args)
        }
        when 'case' {
            my $condition = ast-value(self.evaluate(@plan[1], $subject));
            my $yes = Red::Projection.from-value(self.evaluate(@plan[2], $subject));
            my $no = Red::Projection.from-value(self.evaluate(@plan[3], $subject));
            self.unsupported('Conditional projections must have the same shape')
                unless $yes.signature eq $no.signature;
            my @yes = $yes.leaves;
            my @no = $no.leaves;
            my @leaves = @yes.kv.map(-> $i, $value {
                my Red::AST %when{Red::AST};
                %when{$condition} = $value;
                Red::AST::Case.new(:%when, :else(@no[$i]))
            });
            $yes.construct(@leaves)
        }
        default { self.unsupported('Unknown compiled query expression') }
    }
}

method branches($subject --> Hash:D) {
    my $*RED-INTERNAL = True;
    my $outer-updates = try @*UPDATE;
    my @updates;
    my $value;
    {
        my @*UPDATE := @updates;
        my %*RED-COMPILER-LOCALS;
        $value = &!builder.DEFINITE ?? &!builder(self, $subject)
            !! self.evaluate(@!plan, $subject);
    }
    self.unsupported('Update effects require a map update context')
        if @updates && !$outer-updates.DEFINITE;
    $outer-updates.append: @updates if @updates;
    my Red::AST %branches{Red::AST};
    %branches{Red::AST} = ast-value($value);
    my $report = try $*RED-COMPILER-REPORT;
    $report(:status<used>, :plan(@!plan),
        :engine(&!builder.DEFINITE ?? 'direct' !! 'interpreted')) if $report ~~ Callable;
    %branches
}
