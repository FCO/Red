use Red::AST;
use Red::Model;
use Red::AST::Union;
use Red::AST::Intersect;
use Red::AST::Minus;
unit class Red::AST::Select does Red::AST;

has Mu:U        $.of;
has Red::AST    $.filter;
has Red::AST    @.order;
has Int         $.limit;
has Red::AST    @.group;
has             @.table-list;

method returns { Red::Model }

method args { $!of, $!filter, |@!order }

method tables(::?CLASS:D:) {
    |($!of, |@!table-list, |(.tables with $!filter), callsame).grep(-> \v { v !=:= Nil }).unique
}
method find-column-name {}

method union($sel) {
    my $union = Red::AST::Union.new;
    $union.union: self;
    $union.union: $sel;
    $union
}

method intersect($sel) {
    my $union = Red::AST::Intersect.new;
    $union.intersect: self;
    $union.intersect: $sel;
    $union
}

method minus($sel) {
    my $union = Red::AST::Minus.new;
    $union.minus: self;
    $union.minus: $sel;
    $union
}
