use Red::AST;
use Red::AST::Value;
use Red::Column;
use Red::Model;
unit class Red::AST::Update does Red::AST;

has Str         $.into;
has             %.values;
has Red::AST    $.filter;

method args { |%!values.keys }

multi method new(Red::Model $model) {
    die "No data to be updated on object of type '{ $model.^name }'." unless $model.^is-dirty;
    ::?CLASS.bless:
        :into($model.^table),
        :filter($model.^id-filter),
        :values($model.^dirty-columns.keys.map(-> $column {
            $column.column.name => Red::AST::Value.new:
                :type($column.type),
                :value($column.get_value: $model),
        }).Hash)
}
