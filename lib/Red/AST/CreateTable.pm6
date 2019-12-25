use Red::AST;
use Red::Column;
use Red::AST::Constraints;
use Red::AST::TableComment;

#| Represents a create table
unit class Red::AST::CreateTable does Red::AST;

has Str                     $.name;
has Bool                    $.temp;
has Red::Column             @.columns;
has Red::AST::Constraint    @.constraints;
has Red::AST::TableComment  $.comment;

method returns { Nil }
method args { |@!columns }
method find-column-name {}
