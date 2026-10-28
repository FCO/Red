use Red;
unit module CompilerCallableFixture;
CHECK red-compile;

sub above-one($value) { $value > 1 }
my &predicate = -> $row { $row.value > 1 };

sub fixture-helper-query($model) is export {
    $model.^all.grep({ above-one(.value) })
}
sub fixture-named-query($model) is export {
    $model.^all.grep(&predicate)
}
