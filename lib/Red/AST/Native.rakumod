use Red::AST;
use Red::AST::Value;
use Red::AST::Unary;
use Red::AST::Infixes;
use X::Red::Exceptions;

unit module Red::AST::Native;

#| A native SQL operator, available to queries and DDL without raw SQL values.
class Operator does Red::AST {
    has Str $.operator is required;
    has Red::AST $.left is required;
    has Red::AST $.right is required;
    method returns { Bool }
    method args { $!left, $!right }
    method not { Red::AST::Not.new: self }
    method find-column-name { |$!left.find-column-name, |$!right.find-column-name }
}

sub sql-operator(Str:D $operator, $left, $right --> Red::AST) is export {
    X::Red::Index.new(:reason("Unsupported native operator: $operator")).throw
        unless $operator ~~ /^ <[!%&*+.\/:<=>?@^|~\-]>+ $/
            && !$operator.contains('--') && !$operator.contains('/*')
            && !$operator.contains('*/');
    Operator.new(:$operator, :left(ast-value($left)), :right(ast-value($right)))
}

# These constructors deliberately avoid Boolean optimizations that assume NULL
# behaves like False. CHECK predicates must retain SQL's three-valued logic.
sub sql-and($left, $right --> Red::AST) is export {
    Red::AST::AND.bless(:left(ast-value($left)), :right(ast-value($right)))
}

sub sql-or($left, $right --> Red::AST) is export {
    Red::AST::OR.bless(:left(ast-value($left)), :right(ast-value($right)))
}

sub sql-not($value --> Red::AST) is export {
    Red::AST::Not.new(ast-value($value))
}
