use Red::AST;
use Red::AST::Value;
use Red::Column;
use Red::Model;
unit class Red::AST::Delete does Red::AST;

has Str         $.from;
has Red::AST    $.filter;

method args { Empty }

multi method new(Red::Model:D $model) {
    ::?CLASS.bless:
        :from($model.^table),
        :filter($model.^id-filter),
}

multi method new(Red::Model:U $model, Red::AST $filter?) {
    ::?CLASS.bless:
        :from($model.^table),
        :$filter,
}
