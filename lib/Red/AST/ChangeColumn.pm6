use Red::AST;
unit class Red::AST::ChangeColumn does Red::AST;

has Str  $.table is required;
has Str  $.name  is required;
has Str  $.type  is required;
has Bool $.nullable;
has Bool $.pk;
has Bool $.unique;
has Str  $.ref-table;
has Str  $.ref-col;

method find-column-name {}
method args {}
method returns {}
