use Red::AST;
use Red::AST::Value;
use Red::Column;
use Red::Model;
use X::Red::Exceptions;

#| Represents an update operation
unit class Red::AST::Update does Red::AST;

has Red::Model $.model;
has Str        $.into = $!model.^table;
has Pair       @.values;
has Red::AST   $.filter;

method returns { Nil }
method args { |@!values, $.filter }

multi method new(Red::Model $model) {
    do given $model {
        die "No data to be updated on object of type '{ .^name }'." unless .^is-dirty;
        my Pair @values := Array[Pair].new: .^dirty-columns.keys.map({
            .column => ast-value :type(.type), .column.deflate.(.get_value: $model),
        });
        my $filter = .^id-filter;
        X::Red::UpdateNoId.new.throw without $filter;

        self.bless:
                :model($_),
                :$filter,
                :@values
    }
}
method find-column-name {}
