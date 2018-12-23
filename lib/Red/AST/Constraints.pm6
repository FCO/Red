use Red::AST;
use Red::Column;

class Red::AST::Constraint does Red::AST {
    has Red::Column @.columns;

    method returns { Nil }
    method args { |@!columns }
    method find-column-name {}
}

class Red::AST::Unique is Red::AST::Constraint {}
class Red::AST::Pk     is Red::AST::Constraint {}
