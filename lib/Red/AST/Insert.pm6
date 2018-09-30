use Red::AST;
use Red::AST::Value;
use Red::Column;
use Red::Model;
unit class Red::AST::Insert does Red::AST;

has Red::Model  $.into;
has             %.values;

method args { |%!values.keys }

multi method new(Red::Model $model) {
    ::?CLASS.bless: :into($model.WHAT), :values($model.^columns.keys.map(-> $column {
        $column.column.name => Red::AST::Value.new: :type($column.type), :value($column.get_value: $model)
    }).Hash)
}
