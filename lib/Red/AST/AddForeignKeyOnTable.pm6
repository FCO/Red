use Red::Column;
unit class Red::AST::AddForeignKeyOnTable does Red::AST;

class Fk {
    has Str         $.name is required;
    has Red::Column $.from is required;
    has Red::Column $.to   is required;
}

has Str $.table;
has Fk  @.foreigns;

method new(:$table, :@foreigns) {
    self.bless: :$table, :foreigns(Array[Fk].new: @foreigns.map: {
        Fk.new: :from(.<from>), :to(.<to>), |(:name($_) with .<name>),
    })
}

method args {}

method returns {}

method find-column-name {}