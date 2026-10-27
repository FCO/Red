use Red::AST;
use Red::AST::Unary;
use Red::QueryPlan::Cache;

unit module Red::AST::BoundFilter;

#| An immutable parameter position in a shared predicate.
class Parameter does Red::AST {
    has Int $.index is required;
    has Mu:U $.type is required;
    method returns { $!type }
    method args { () }
    method find-column-name { () }
}

#| A model member resolved only after the query receiver and alias are known.
class Field does Red::AST {
    has Str $.name is required;
    method returns { Any }
    method args { () }
    method find-column-name { () }
}

#| A bind descriptor retained by a SQL plan, never a captured value.
class Bind {
    has Int $.group is required;
    has Int $.index is required;
}

class Binding {}

#| A private set of captures attached to a shared predicate tree.
class Predicate does Red::AST {
    has Binding $.binding-token .= new;
    has Red::AST $.filter is required;
    has List $.values is required;
    has Red::QueryPlan::Cache $.cache is required;
    multi method WHICH(::?CLASS:D:) { $!binding-token.WHICH }
    method not { Red::AST::Not.new(self) }
    method returns { Bool }
    method args { $!filter }
    method find-column-name { $!filter.find-column-name }
}
