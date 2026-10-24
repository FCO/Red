use Red::Compiler::Template;
use Red::HiddenFromSQLCommenting;

#| Dispatches an instrumented call without passing Red metadata to other receivers.
unit class Red::Compiler::Runtime;

has $.receiver;

method dispatch(Str $method, Capture $arguments) is raw is hidden-from-sql-commenting {
    my $allowed = try $*RED-DONT-FAIL-WITHOUT-OPERATORS;
    if $!receiver ~~ ::('Red::ResultSeq') {
        my $template = $arguments<red-ast>;
        my $*RED-DONT-FAIL-WITHOUT-OPERATORS = so ($allowed || $template.operators);
        $!receiver."$method"(|$arguments)
    } else {
        my %named = $arguments.hash;
        %named<red-ast>:delete;
        $!receiver."$method"(|$arguments.list, |%named)
    }
}

method map(|args) is raw is hidden-from-sql-commenting { self.dispatch('map', args) }
method grep(|args) is raw is hidden-from-sql-commenting { self.dispatch('grep', args) }
method first(|args) is raw is hidden-from-sql-commenting { self.dispatch('first', args) }
method sort(|args) is raw is hidden-from-sql-commenting { self.dispatch('sort', args) }
