use Red::AST;
use Red::AST::Comment;
use Red::Projection;
unit class Red::AST::Chained does Red::AST;

has Red::AST            $.filter;
has Int                 $.limit;
has Int                 $.offset is rw;
has                     &.post;
has Red::AST            @.order;
has Red::AST            @.group;
has                     @.table-list;
has Red::AST::Chained   $.next;
has Red::AST            $.source;
has Str                 $.source-alias;
has Red::Projection     $.projection;
has Bool                $.projection-bound = False;
has Int                 $.projection-depth = 0;
has Red::AST            @.fields;
has Red::AST            @.row-identity;
has Bool                $.identity-lost = False;

method args {
    $!filter, |@!order, |@!group, |(.args with $!next)
}

method returns {}
method find-column-name {}
