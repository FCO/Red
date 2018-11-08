use Red::AST;
use Red::Model;
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
    |($!of, |@!table-list, callsame).grep(-> \v { v !=:= Nil }).unique
}
