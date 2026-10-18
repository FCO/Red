use Red::AST;
use Red::AST::Value;
use Red::AST::Unary;
use Red::AST::Infixes;
use X::Red::Exceptions;

unit module Red::AST::Native;

#| A PostgreSQL operator, available to queries and DDL without raw SQL values.
class Operator does Red::AST {
    has Str $.operator is required;
    has Red::AST $.left is required;
    has Red::AST $.right is required;
    method returns { Bool }
    method args { $!left, $!right }
    method not { Red::AST::Not.new: self }
    method find-column-name { |$!left.find-column-name, |$!right.find-column-name }
}

#| A PostgreSQL range constructor with SQL expression arguments.
class Range does Red::AST {
    has Str $.range-type = 'numrange';
    has Red::AST @.values;
    method returns { Str }
    method args { |@!values }
    method find-column-name { @!values.map(*.find-column-name).flat }
}

sub sql-operator(Str:D $operator, $left, $right --> Red::AST) is export {
    X::Red::Index.new(:reason("Unsupported native operator: $operator")).throw
        unless $operator eq any('@>', '<@', '&&', '~', '~*', '!~', '!~*',
            '=', '<>', '<', '<=', '>', '>=');
    Operator.new(:$operator, :left(ast-value($left)), :right(ast-value($right)))
}

sub sql-range($lower, $upper, Str :$bounds = '[)', Str :$type = 'numrange' --> Red::AST)
    is export {
    X::Red::Index.new(:reason('Invalid PostgreSQL range constructor')).throw
        unless $type eq any(<numrange int4range int8range tsrange tstzrange daterange>)
            && $bounds eq any('[)', '[]', '(]', '()');
    Range.new(:range-type($type), :values[
        ast-value($lower), ast-value($upper), ast-value($bounds)
    ])
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
