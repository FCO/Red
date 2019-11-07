use Red::AST;
use Red::AST::Value;
use Red::Column;
use Red::Model;
unit class Red::AST::Update does Red::AST;

has Str      $.into;
has Pair     @.values;
has Red::AST $.filter;

method returns { Nil }
method args { |@!values }

multi method new(Red::Model $model) {
    do given $model {
        die "No data to be updated on object of type '{ .^name }'." unless .^is-dirty;
        self.bless:
                :into(.^table),
                :filter(.^id-filter),
                :values(Array[Pair].new: .^dirty-columns.keys.map({
                    .column => ast-value :type(.type), .column.deflate.(.get_value: $model),
                }))
    }
}
method find-column-name {}
