use Red::AST;
use Red::AST::MultiSelect;

#| Represents a select minus other select
unit class Red::AST::Minus does Red::AST::MultiSelect;

has Red::AST @.selects;

method new(*@selects) {
    nextwith :selects(Array[Red::AST].new: |@selects)
}

method returns { Red::Model }

method args { flat @!selects>>.args }

method tables(::?CLASS:D:) {
    (flat @!selects».?tables).grep(-> \v { v !=:= Nil }).unique
}
method find-column-name {}

method minus($sel) {
    if $sel ~~ ::?CLASS {
        self.minus: $_ for $sel.selects
    } else {
        self.selects.push: $sel
    }
    self
}
