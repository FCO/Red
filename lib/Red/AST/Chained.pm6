use Red::AST;
unit class Red::AST::Chained does Red::AST;

has Red::AST            $.filter;
has Int                 $.limit;
has                     &.post;
has Red::AST            @.order;
has Red::AST            @.group;
has                     @.table-list;
has Red::AST::Chained   $.next;

method args {
    $!filter, |@!order, |@!group, |$!next.args
}

method returns {}
