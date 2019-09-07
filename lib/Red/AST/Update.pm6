use Red::AST;
use Red::AST::Value;
use Red::Column;
use Red::Model;
unit class Red::AST::Update does Red::AST;

has Str         $.into;
has             %.values;
has Red::AST    $.filter;

method returns { Nil }
method args { |%!values.keys }

multi method new(Red::Model $model) {
    die "No data to be updated on object of type '{ $model.^name }'." unless $model.^is-dirty;
    ::?CLASS.bless:
        :into($model.^table),
        :filter($model.^id-filter),
        :values($model.^dirty-columns.keys.map(-> $column {
            #next without $column.get_value: $model;
            $column.column.name => ast-value :type($column.type), $column.get_value: $model,
        }).Hash)
}
method find-column-name {}
