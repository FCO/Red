use Red::AST;
use Red::Column;
unit class Red::AST::Chained does Red::AST;

has Red::AST            $.filter;
has Int                 $.limit;
has                     &.post;
has Red::Column         @.order;
has Red::AST            @.group;
has                     @.table-list;
has Red::AST::Chained   $.next;

method returns {}
