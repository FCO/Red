use X::Red::Exceptions;
use Red::AST::RowContext;

unit module Red::RowSecurity::Context;

sub row-security-error(Str:D $reason) is export {
    X::Red::RowSecurity.new(:$reason).throw
}

sub row-security-context() is export {
    my $scoped = DYNAMIC::<$*RED-ROW-CONTEXT>;
    return $scoped if $scoped.DEFINITE;
    my $default = DYNAMIC::<%*RED-CONTEXT>;
    $default.DEFINITE ?? capture-row-context($default) !! Map.new
}

# Copy containers and reject references whose contents could change after capture.
sub capture-row-context(Associative:D $context --> Map:D) is export {
    my %copy;
    for $context.kv -> $key, $value {
        row-security-error("Context value '$key' must be a defined immutable scalar")
            unless $value.DEFINITE && ($value.WHAT === Str || $value.WHAT === Bool
                || $value.WHAT === Int || $value.WHAT === Rat || $value.WHAT === Num);
        %copy{$key} = $value;
    }
    Map.new(%copy)
}

sub assert-row-context($captured) is export {
    my $current = row-security-context();
    row-security-error('Row security context changed between creation and execution')
        unless $captured.DEFINITE && $current.DEFINITE && $captured eqv $current;
}

# A policy must distinguish a missing key from a SQL NULL.
class PolicyContext does Associative {
    has Map $.values is required;
    has Bool $.symbolic = False;
    method AT-KEY($key) {
        return Red::AST::RowContext.new(:key($key.Str)) if $!symbolic;
        row-security-error("Missing row security context key '$key'")
            unless $!values{$key}:exists;
        $!values{$key}
    }
    method EXISTS-KEY($key) { $!values{$key}:exists }
    method keys { $!values.keys }
    method kv { $!values.kv }
    method pairs { $!values.pairs }
    method iterator { $!values.iterator }
    method elems { $!values.elems }
}

sub policy-context(Bool :$symbolic = False) is export {
    return PolicyContext.new(:values(Map.new), :symbolic) if $symbolic;
    my $context = row-security-context();
    row-security-error('A row security context is required') unless $context ~~ Map:D;
    PolicyContext.new(:values($context))
}
