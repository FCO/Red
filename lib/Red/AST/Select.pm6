use Red::AST;
use Red::Column;
unit class Red::AST::Select does Red::AST;

has Mu:U        $.of;
has Red::AST    $.filter;
has Red::Column @.order;
has Int         $.limit;
has             @.table-list;

method args { $!of, $!filter, |@!order }

method tables(::?CLASS:D:) {
    |($!of, |@!table-list, callsame).grep(-> \v { v !=:= Nil }).unique
}
