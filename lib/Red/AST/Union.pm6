use Red::AST;
use Red::AST::MultiSelect;
unit class Red::AST::Union does Red::AST::MultiSelect;

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

method union($sel) {
    if $sel ~~ ::?CLASS {
        self.union: $_ for $sel.selects
    } else {
        self.selects.push: $sel
    }
    self
}
