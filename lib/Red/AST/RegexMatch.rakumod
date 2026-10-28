use Red::AST;
use Red::Regex;
use Red::AST::Unary;
use Red::AST::Value;
use Red::AST::Case;
use Red::AST::IsDefined;
use X::Red::Exceptions;

#| A regex predicate carrying a data-only tree, rendered by the SQL driver.
unit class Red::AST::RegexMatch does Red::AST;

has Red::AST $.value is required;
has $.pattern is required;
method returns { Bool }
method args { $!value, $!pattern }
method not { Red::AST::Not.new(self) }
method find-column-name { $!value.find-column-name }

method checked(::?CLASS:U: Red::AST $value is copy, $pattern where Str:D | Red::Regex:D) {
    X::Red::Compiler::Unsupported.new(:fatal, :reason('SQL regex requires a non-nullable column')).throw
        if $value ~~ ::('Red::Column') && $value.nullable;
    my $type = $value.returns;
    $type = $type.^refinee while $type.HOW ~~ Metamodel::SubsetHOW;
    if $type === Numeric || $type === Real || $type === Int || $type === UInt || $type === Num || $type === Rat || $type === FatRat {
        # SQL owns numeric formatting; no custom Raku stringifier is invoked.
        $value = Red::AST::Cast.new($value, 'text', :bind);
    } elsif $type === Bool {
        my $null = Red::AST::Cast.new(ast-value(Any), 'text');
        if $value ~~ Red::AST::Value && !$value.value.defined {
            $value = $null;
        } elsif $value ~~ Red::AST::Value && $value.value.WHAT === Bool && !$value.column.defined {
            $value = ast-value($value.value.Str);
        } else {
            my Red::AST %when{Red::AST};
            %when{Red::AST::IsDefined.new($value).not} = $null;
            %when{$value} = ast-value('True');
            $value = Red::AST::Case.bless(:%when, :else(ast-value('False')));
        }
    }
    X::Red::Compiler::Unsupported.new(:fatal,
        :reason('SQL regex requires text or a primitive numeric/Boolean expression')).throw
        unless $value.returns ~~ Str;
    self.new(:$value, :$pattern)
}
