use Red::AST;
use Red::AST::MultiSelect;

#| Represents a intersect between 2 (or more) selects
unit class Red::AST::Intersect does Red::AST::MultiSelect;

has Red::AST @.selects;

method new(*@selects) {
    nextwith :selects(Array[Red::AST].new: |@selects)
}

method returns { Red::Model }

method args { flat @!selects>>.args }

method tables(::?CLASS:D:) {
    (flat @!selects>>.tables).unique
}
method find-column-name {}

method intersect($sel) {
    if $sel ~~ ::?CLASS {
        self.intersect: $_ for $sel.selects
    } else {
        self.selects.push: $sel
    }
    self
}
