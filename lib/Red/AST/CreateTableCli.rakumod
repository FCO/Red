use Red::AST;
use Red::Cli::Table;

#| Represents a create table
unit class Red::AST::CreateTableCli does Red::AST;

has Red::Cli::Table $.table;

method returns { Nil }
method args { |$!table.columns }
method find-column-name {}
