use Red::DB;

unit role MetamodelX::Red::Populatable;

#| Insert explicit fixture rows. Deflated rows use the same hydration rules as queries.
method fixture-populate($model, :@rows!, Bool :$deflated = False) {
    for @rows -> %row {
        my %values = %row;
        if $deflated {
            my $object = $model.^new-from-data(%row);
            %values = $object.^column-values;
            # NULL must not turn into an attribute's default during creation.
            for $model.^columns -> $attribute {
                my $name = $attribute.column.attr-name;
                %values{$name} = $attribute.type unless %row{$name}.defined;
            }
        }
        $model.^create(|%values);
    }
    True
}

method populate($model, :$rows, Bool :$deflated = False, |) {
    return Nil unless $rows.defined;
    self.fixture-populate($model, :rows($rows), :$deflated)
}
