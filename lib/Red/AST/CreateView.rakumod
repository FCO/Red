use Red::AST;
use Red::AST::TableComment;
use Red::AST::Select;

#| Represents a create table
unit class Red::AST::CreateView does Red::AST;

has Str                     $.name;
has Bool                    $.temp;
has Str                     $.select;
has Red::AST                $.ast;
has Red::AST::TableComment  $.comment;

method returns { Nil }
method args { }
method find-column-name {}

