use Red::AST;
use Red::DB;
use Red::AST::BoundFilter;
use Red::QueryPlan::Cache;
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

sub compiler-warnings-enabled(Bool $explicit = Bool --> Bool:D) is export {
    return $explicit if $explicit.DEFINITE;
    my $dynamic = DYNAMIC::<$*RED-COMPILER-WARN>;
    return $dynamic if $dynamic ~~ Bool:D;
    my $environment = %*ENV<RED_COMPILER_WARN>;
    return False unless $environment.DEFINITE && $environment.chars;
    so $environment.trim.lc eq any(<1 true yes on>)
}

sub emit-compiler-warning(&callback, $template, Str:D :$method!, Str:D :$reason!
    --> Bool:D) is export {
    my $explicit = $template.DEFINITE ?? $template.warn !! Bool;
    return False unless compiler-warnings-enabled($explicit);
    my $name = $template.DEFINITE && $template.query-method.chars
        ?? $template.query-method !! $method;
    my $source = $template.DEFINITE && $template.source.chars
        ?? $template.source !! ((try &callback.raku) // '<callback>');
    my $file = (try &callback.file) // '<unknown>';
    my $line = (try &callback.line) // 0;
    warn "red-compile: $name at $file:$line uses symbolic evaluation: $reason\n$source";
    True
}

#| A query expression compiled independently of SQL aliases and closure instances.

has @.plan;
has @.getters;
has @.values;
has Bool $.bound = False;
has Bool $.operators = False;
has Bool $.prevalidate = True;
has Bool $.warn;
has Str $.query-method = '';
has Str $.source = '';
has Str $.unsupported-reason;
has &.builder;
has &.validator;
has Red::QueryPlan::Cache $.filter-cache .= new;
has Red::QueryPlan::Cache $.sql-cache .= new;
has Str $!filter-shape-key;
has Red::AST $.filter-prototype;

submethod TWEAK() {
    $!filter-shape-key = @!plan.raku;
    # This object is constructed at CHECK by the RakuAST compiler and embedded
    # in its template literal. Only symbolic slots enter the precompilation.
    if @!plan.elems && @!plan[0] eq 'op' && @!plan[1] eq any(<Eq Ne Lt Le Gt Ge>) {
        my ($left, $right) = @!plan[2, 3];
        sub slot($part) {
            return Red::AST::BoundFilter::Field.new(:name($part[2]))
                if $part[0] eq 'field' && $part[1][0] eq 'subject';
            return Red::AST::BoundFilter::Parameter.new(:index($part[1]), :type(Any))
                if $part[0] eq 'capture';
            Nil
        }
        my $a = slot($left);
        my $b = slot($right);
        $!filter-prototype = ::('Red::AST::' ~ @!plan[1]).new($a, $b)
            if $a.DEFINITE && $b.DEFINITE;
    }
}

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
                    && ($value.^columns.first({ .name.substr(2) eq $name }).DEFINITE
                        || $value.^relationships.keys.first({ .name.substr(2) eq $name }).DEFINITE);
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
    self.unsupported($!unsupported-reason) if $!unsupported-reason.DEFINITE;
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

# Only direct field/scalar comparisons are value-independent in this first version.
# All other expressions retain the existing factory and fallback behavior.
method cached-filter($subject, :$driver = try get-RED-DB) {
    my $*RED-INTERNAL = True;
    my $enabled = DYNAMIC::<$*RED-QUERY-PLAN-CACHE>;
    return Nil if $enabled.WHAT === Bool && !$enabled;
    return Nil unless $driver.DEFINITE && $driver.?supports-query-plans;
    return Nil unless @!plan[0] eq 'op'
        && @!plan[1] eq any(<Eq Ne Lt Le Gt Ge>) && $subject ~~ ::('Red::Model')
        && !$subject.DEFINITE;
    my ($field, $capture) = @!plan[2, 3];
    ($field, $capture) = ($capture, $field) if $field[0] eq 'capture';
    return Nil unless $field[0] eq 'field' && $field[1][0] eq 'subject'
        && $capture[0] eq 'capture' && @!values.elems == 1;
    my $value = @!values[$capture[1]];
    return Nil unless $value.DEFINITE && ($value.WHAT === Int
        || $value.WHAT === Str || $value.WHAT === Rat || $value.WHAT === Num);
    return Nil if $value ~~ Int && ($value < -(2 ** 63) || $value >= 2 ** 63);
    return Nil if $value ~~ Numeric && ($value.Num.isNaN || $value.Num.abs == Inf);
    my $column = $subject.^columns.first({ .name.substr(2) eq $field[2] });
    return Nil unless $column.DEFINITE && ($column.type === Int
        || $column.type === Str || $column.type === Rat || $column.type === Num);
    # Parameter slots cannot replace scalar coercions performed by the source operator.
    my $source-op = @!plan[4] // '';
    return Nil if $source-op eq any('==', '!=', '<', '<=', '>', '>=')
        && !($column.type ~~ Numeric && $value ~~ Numeric);
    return Nil if $source-op eq any(<eq ne lt le gt ge>)
        && !($column.type === Str && $value.WHAT === Str);
    my $key = $subject.WHERE.Str ~ '|' ~ $value.WHAT.WHICH.Str
        ~ '|' ~ $column.WHICH.Str ~ '|' ~ $column.args.raku ~ '|' ~ $!filter-shape-key;
    my $entry = $!filter-cache.fetch($key, {
        if $!filter-prototype.DEFINITE {
            my $parameter = Red::AST::BoundFilter::Parameter.new(
                :index($capture[1]), :type($value.WHAT));
            my $member = $subject."{$field[2]}"();
            my $left-is-field = $!filter-prototype.left
                ~~ Red::AST::BoundFilter::Field;
            my $left = $left-is-field ?? $member !! $parameter;
            my $right = $left-is-field ?? $parameter !! $member;
            @!plan[5] ~~ Callable ?? @!plan[5]($left, $right)
                !! $!filter-prototype.clone(:$left, :$right)
        } else {
            my @values = Red::AST::BoundFilter::Parameter.new(
                :index($capture[1]), :type($value.WHAT));
            self.clone(:@values).branches($subject).values.head
        }
    });
    my $report = DYNAMIC::<$*RED-COMPILER-REPORT>;
    $report(:status('filter-' ~ $entry.key),
        :prototype($!filter-prototype.DEFINITE)) if $report ~~ Callable;
    Red::AST::BoundFilter::Predicate.new(:filter($entry.value),
        :values(@!values.List), :cache($!sql-cache))
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
    my $report = DYNAMIC::<$*RED-COMPILER-REPORT>;
    $report(:status<used>, :plan(@!plan),
        :engine(&!builder.DEFINITE ?? 'direct' !! 'interpreted')) if $report ~~ Callable;
    %branches
}
