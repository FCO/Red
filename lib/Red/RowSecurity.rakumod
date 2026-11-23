use Red::AST;
use Red::AST::Select;
use Red::AST::MultiSelect;
use Red::AST::Insert;
use Red::AST::Update;
use Red::AST::Delete;
use Red::AST::Value;
use Red::AST::RowContext;
use Red::AST::RowParameter;
use CX::Red::Bool;
use Red::AST::ProductSource;
use Red::AST::Infixes;
use Red::AST::Unary;
use Red::Column;
use Red::Model;
use Red::PrepareCode;
use Red::RowSecurity::Context;

unit module Red::RowSecurity;

my constant @operations = <SELECT INSERT UPDATE DELETE>;

sub policy-model(Mu $model) is export {
    return $model unless $model ~~ Red::Model;
    my $original = $model.WHAT;
    my %seen;
    while $original.HOW.^can('orig') && !%seen{$original.WHICH.Str}++ {
        my $next = $original.^orig;
        last if $next === $original;
        $original = $next;
    }
    $original
}

sub row-protected(Mu $model --> Bool:D) is export {
    return False unless $model ~~ Red::Model;
    my $original = policy-model($model);
    so @operations.first({ $original.^can($_ ~ '-ALLOWED-IF') })
}

# Walk storage, rather than .args: source queries and product sources are deliberately
# absent from .args because they own a separate SQL scope.
sub row-query-models(Red::AST:D $query --> List:D) is export {
    my %seen;
    my %models;
    sub visit(Mu $value) {
        if $value ~~ Red::Model {
            %models{$value.WHAT.WHICH.Str} = $value.WHAT;
            return;
        }
        return unless $value.DEFINITE;
        if $value ~~ Red::Column {
            visit($value.class);
            visit($value.computation);
        } elsif $value ~~ Red::AST {
            return if %seen{$value.WHERE}++;
            visit(.get_value($value)) for $value.^attributes;
        } elsif $value.^can('relationship-model') {
            visit($value.relationship-model);
        } elsif $value ~~ Pair {
            visit($value.key);
            visit($value.value);
        } elsif $value ~~ Positional {
            visit($_) for $value.list;
        } elsif $value ~~ Associative {
            visit($_) for $value.values;
        }
    }
    visit($query);
    for %models.values.List -> $model {
        if $model.HOW.^can('tables') {
            visit($_) for $model.^tables.flat;
        }
    }
    %models.values.List
}

sub protected-row-query(Red::AST:D $query --> Bool:D) is export {
    return False if $query.^name ~~ /^ 'Red::AST::' [Create|Drop|Add|Alter|Begin|Commit|Rollback|Savepoint|Release]/;
    row-query-models($query).grep({ row-protected($_) }).elems > 0
}

# Clone the whole AST. Do not mutate a query or a shared template with context values.
sub map-row-ast(Mu $value, &column, :&slot = *.self) is export {
    return column($value) if $value ~~ Red::Column;
    return $value unless $value.DEFINITE;
    if $value ~~ Red::AST {
        return slot($value) if $value ~~ Red::AST::Value | Red::AST::RowContext
            | Red::AST::RowParameter;
        my %attributes = $value.^attributes.map({
            .name.substr(2) => map-row-ast(.get_value($value), &column, :&slot)
        });
        return $value.clone(|%attributes);
    }
    return Pair.new(map-row-ast($value.key, &column, :&slot),
        map-row-ast($value.value, &column, :&slot)) if $value ~~ Pair;
    return $value.map({ map-row-ast($_, &column, :&slot) }).Array if $value ~~ Positional;
    return $value;
}

sub validate-row-predicate(Red::AST:D $predicate, @models) {
    my %allowed-models = @models.map({ .WHICH.Str => True });
    sub visit(Red::AST:D $node) {
        return if $node ~~ Red::AST::RowContext;
        if $node ~~ Red::Column {
            row-security-error('A row policy may only refer to its own row columns')
                unless %allowed-models{$node.class.WHICH.Str}:exists;
            row-security-error('Computed columns are not supported in row policies')
                if $node.computation.DEFINITE;
            return;
        }
        if $node ~~ Red::AST::Cast {
            row-security-error('Unsupported row policy cast')
                unless $node.type eq any(<num str int>);
            visit($node.value);
            return;
        }
        if $node ~~ Red::AST::Value {
            my $value = $node.value;
            row-security-error('A row policy returned an unsupported value')
                unless !$value.DEFINITE || $value.WHAT === Bool || $value.WHAT === Int
                    || $value.WHAT === Rat || $value.WHAT === Num || $value.WHAT === Str;
            return;
        }
        row-security-error('Unsupported row policy expression: ' ~ $node.^name)
            unless $node.^name eq any(<Red::AST::Eq Red::AST::Ne Red::AST::Lt
                Red::AST::Le Red::AST::Gt Red::AST::Ge Red::AST::AND Red::AST::OR
                Red::AST::Not Red::AST::So>);
        visit($_) for $node.args.grep(Red::AST:D);
    }
    visit($predicate);
}

sub row-expression-key(Red::AST:D $node --> Str:D) {
    return ['column', $node.class.WHICH.Str, $node.name].raku if $node ~~ Red::Column;
    return ['context', $node.key].raku if $node ~~ Red::AST::RowContext;
    return ['value', $node.value.WHAT.^name, $node.value.raku].raku
        if $node ~~ Red::AST::Value;
    return ['cast', $node.type, row-expression-key($node.value)].raku
        if $node ~~ Red::AST::Cast;
    [$node.^name, |$node.args.map({ row-expression-key($_) })].raku
}

class PolicyBranch is Exception {
    has Red::AST $.condition is required;
    method message { 'Internal row policy decision' }
}

sub bind-row-policy(Red::AST:D $predicate --> Red::AST:D) is export {
    my $context = policy-context();
    map-row-ast($predicate, *.self, :slot(-> $node {
        if $node ~~ Red::AST::RowContext {
            Red::AST::RowParameter.new(:value($context{$node.key}))
        } elsif $node ~~ Red::AST::Value {
            Red::AST::RowParameter.new(:value($node.get-value))
        } else {
            $node
        }
    }))
}

sub row-predicate(Mu $model, Str:D $operation, Mu :$new, Bool :$symbolic = False
    --> Red::AST:D) is export {
    policy-context() unless $symbolic;
    my $context = policy-context(:symbolic);
    my $original = policy-model($model);
    my $name = $operation ~ '-ALLOWED-IF';
    my $method = $original.^lookup($name);
    return ast-value(True) unless $method.DEFINITE;
    my $*RED-INTERNAL = True;
    my $*RED-ROW-POLICY-COMPILING = True;
    my Int $evaluations = 0;
    sub constant($node, Bool $value --> Bool:D) {
        so ($node ~~ Red::AST::Value && $node.value.WHAT === Bool && $node.value === $value)
    }
    sub and-row($left, $right) { Red::AST::AND.bless(:$left, :$right) }
    sub or-row($left, $right) { Red::AST::OR.bless(:$left, :$right) }
    sub choose($condition, $no, $yes --> Red::AST:D) {
        return $no if row-expression-key($no) eq row-expression-key($yes);
        # Preserve SQL boolean expressions for Raku's value-returning && and ||.
        return and-row($condition, $yes) if row-expression-key($no) eq row-expression-key($condition);
        return or-row($condition, $no) if row-expression-key($yes) eq row-expression-key($condition);
        return $condition if constant($no, False) && constant($yes, True);
        return Red::AST::Not.new($condition) if constant($no, True) && constant($yes, False);
        return and-row($condition, $yes) if constant($no, False);
        return or-row($condition, $no) if constant($yes, True);
        return and-row(Red::AST::Not.new($condition), $no) if constant($yes, False);
        return or-row(Red::AST::Not.new($condition), $yes) if constant($no, True);
        or-row(and-row($condition, $yes),
            and-row(Red::AST::Not.new($condition), $no))
    }
    sub evaluate(%choices --> Red::AST:D) {
        row-security-error('Row policy is too complex to compile') if ++$evaluations > 256;
        my %*VALS{Red::AST};
        my @*UPDATE;
        my $result;
        my $branch;
        {
            {
                $result = $new ~~ Red::Model
                    ?? $method($original, $new, $context) !! $method($original, $context);
                CONTROL {
                    when CX::Red::Bool {
                        my $key = row-expression-key(.ast);
                        if %choices{$key}:exists {
                            %*VALS{.ast} = %choices{$key};
                            .resume;
                        }
                        PolicyBranch.new(:condition(.ast)).throw;
                    }
                }
            }
            CATCH {
                when PolicyBranch { $branch = .condition }
            }
        }
        row-security-error('Row policy methods cannot mutate columns') if @*UPDATE;
        if $branch.DEFINITE {
            my %no = %choices;
            my %yes = %choices;
            %no{row-expression-key($branch)} = False;
            %yes{row-expression-key($branch)} = True;
            return choose($branch, evaluate(%no), evaluate(%yes));
        }
        row-security-error('A policy must return a boolean or SQL predicate')
            unless $result ~~ Red::AST || $result.WHAT === Bool;
        ast-value($result)
    }
    my %choices;
    my $predicate = evaluate(%choices);
    row-security-error('A row policy must produce a boolean expression')
        unless $predicate ~~ Red::AST::RowContext || $predicate.returns === Bool;
    my @old-models = $original.^mro.grep({ $_ ~~ Red::Model });
    my %old-models = @old-models.map({ .WHICH.Str => True });
    validate-row-predicate($predicate, [|@old-models, |($new if $new ~~ Red::Model)]);
    $predicate = map-row-ast($predicate, -> $column {
        if %old-models{$column.class.WHICH.Str}:exists {
            my $attribute = $model.^columns.first(*.column.name eq $column.name);
            row-security-error('A policy column is absent from the query source') unless $attribute.DEFINITE;
            $attribute.column.clone(:model($model.WHAT), :class($model.WHAT))
        } else {
            $column
        }
    });
    return $predicate if $symbolic;
    my $bound = bind-row-policy($predicate);
    row-security-error('A row policy context predicate must be boolean')
        unless $bound.returns === Bool;
    return $bound;
    CATCH {
        when X::Red::RowSecurity { .rethrow }
        default { row-security-error("Invalid $operation policy: { .message }") }
    }
}

sub secure-row-query($driver, Red::AST:D $query --> Red::AST:D) is export {
    return $query unless protected-row-query($query);
    policy-context();
    row-security-error('This driver does not implement row security')
        unless $driver.row-security-capabilities<filter>;
    $driver.prepare-row-security(row-query-models($query).grep({ row-protected($_) }).List);
    row-security-error('Protected writes require atomic row security execution')
        unless $query ~~ Red::AST::Select | Red::AST::MultiSelect
            | ::('Red::AST::LastInsertedRow');
    sub secure(Mu $value) {
        return $value unless $value.DEFINITE;
        if $value ~~ Red::AST::Select {
            my %policies;
            for row-query-models($value).grep({ row-protected($_) }) -> $model {
                row-security-error('Protected virtual sources are not supported')
                    if $model.HOW.^name.contains('VirtualView');
                %policies{$model.^as} = row-predicate($model, 'SELECT');
            }
            my %attributes = $value.^attributes.grep(*.name ne '%!row-policies').map({
                .name.substr(2) => secure(.get_value($value))
            });
            return $value.clone(|%attributes, :row-policies(%policies));
        }
        if $value ~~ Red::AST::ProductSource && row-protected($value.model) {
            return $value.clone(:row-policy(row-predicate($value.model, 'SELECT')));
        }
        if $value ~~ Red::AST::Value && $value.value ~~ Red::AST:D {
            return $value.clone(:value(secure($value.value)));
        }
        if $value ~~ Red::AST && $value !~~ Red::Column && $value !~~ Red::AST::Value {
            return $value.clone(|$value.^attributes.map({
                .name.substr(2) => secure(.get_value($value))
            }).Hash);
        }
        return $value.map({ secure($_) }).Array if $value ~~ Positional;
        return $value;
    }
    secure($query)
}

# Portable representation, independent of model instances, aliases and caller values.
sub row-policy-descriptors(Mu $model --> Hash:D) is export {
    return {} unless row-protected($model);
    my $original = policy-model($model);
    my %policies;
    for @operations -> $operation {
        my $new = $operation eq 'UPDATE'
            ?? $original.^alias('red_security_new', :!cache) !! Any;
        my $predicate = row-predicate($original, $operation, :$new, :symbolic);
        sub describe($node) {
            return ['context', $node.key] if $node ~~ Red::AST::RowContext;
            return ['column', ($node.class === $new ?? 'new' !! 'old'), $node.name]
                if $node ~~ Red::Column;
            return ['value', $node.value] if $node ~~ Red::AST::Value;
            return ['cast', $node.type, describe($node.value)] if $node ~~ Red::AST::Cast;
            [$node.^name.split('::').tail.lc, |$node.args.map({ describe($_) })]
        }
        %policies{$operation.lc} = describe($predicate);
    }
    %policies
}
