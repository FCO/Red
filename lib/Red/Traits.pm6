use Red::Column;
use Red::Attr::Column;
use Red::ResultSeq;
use Red::Phaser;
unit module Red::Traits;

=head2 Red::Traits

#| This trait marks the corresponding table of the
#| model as TEMPORARY (so it only exists for the time
#| of Red being connected to the database).
multi trait_mod:<is>(Mu:U $model, Bool :$temp! --> Empty) {
    $model.^temp = True;
}

multi trait_mod:<is>(Mu:U $model, Str:D :$rs-class! --> Empty) {
    trait_mod:<is>($model, :rs-class(::($rs-class)))
}

multi trait_mod:<is>(Mu:U $model, Mu:U :$rs-class! --> Empty) {
    die "{$rs-class.^name} should do the Red::ResultSeq role" unless $rs-class ~~ Red::ResultSeq;
    my role RSClass[Mu:U $rclass] { method rs-class(|) { $rclass<> } }
    $model.HOW does RSClass[$rs-class];
}

#| This trait configures all model attributes (columns) to be NULLABLE by default, when used as `is nullable`.
#| Without this trait applied, default for every attribute (column) is NOT NULL,
#| though it can be stated explicitly with writing `is !nullable` for the model.
#| Defaults can be overridden using `is nullable` or `is !nullable` for the attribute (column) itself.
multi trait_mod:<is>(Mu:U $model, Bool :$nullable! --> Empty) {
    $model.HOW does role :: { method default-nullable(|) { $nullable } }
}

multi trait_mod:<is>(Attribute $attr, Bool :$column! --> Empty) is export {
    trait_mod:<is>($attr, :column{}) if $column
}

multi trait_mod:<is>(Attribute $attr, Str :$column! --> Empty) is export {
    trait_mod:<is>($attr, :column{:name($column)}) if $column
}

#| This trait marks an attribute (column) as SQL PRIMARY KEY.
multi trait_mod:<is>(Attribute $attr, Bool :$id! where $_ == True --> Empty) is export {
    trait_mod:<is>($attr, :column{:id, :!nullable})
}

#| This trait marks an attribute (column) as SQL PRIMARY KEY with SERIAL data type, which
#| means it auto-increments on each insertion.
multi trait_mod:<is>(Attribute $attr, Bool :$serial! where $_ == True --> Empty) is export {
    trait_mod:<is>($attr, :column{:id, :!nullable, :auto-increment})
}

#| A generic trait used for customizing a column. It accepts a hash of Bool keys.
#| Possible values include:
#| * id - marks a column PRIMARY KEY
#| * auto-increment - marks a column AUTO INCREMENT
#| * nullable - marks a column as NULLABLE
#| * TBD
multi trait_mod:<is>(Attribute $attr, :%column! --> Empty) is export {
    $attr does Red::Attr::Column(%column);
}

multi trait_mod:<is>(Attribute $attr, :&referencing! --> Empty) is export {
    trait_mod:<is>($attr, :column{ :nullable, :references(&referencing) })
}

multi trait_mod:<is>(Attribute $attr, :$referencing! (&referencing!, Str :$model!, Str :$require = $model ) --> Empty) is export {
    trait_mod:<is>($attr, :column{ :nullable, :references(&referencing), model-name  => $model, :$require })
}

multi trait_mod:<is>(Attribute $attr, :$referencing! (Str :$model!, Str :$column!, Str :$require = $model ) --> Empty) is export {
    trait_mod:<is>($attr, :column{ :nullable, model-name => $model, column-name => $column, :$require })
}

#| This trait allows setting a custom name for a table corresponding to a model.
#| For example, `model MyModel is table<custom_table_name> {}` will use `custom_table_name`
#| as the name of the underlying database table.
multi trait_mod:<is>(Mu:U $model, Str :$table! where .chars > 0 --> Empty) {
    $model.HOW.^attributes.first({ .name eq '$!table' }).set_value($model.HOW, $table)
}

multi trait_mod:<is>(Attribute $attr, :&relationship! --> Empty) is export {
    $attr.package.^add-relationship: $attr, &relationship
}

multi trait_mod:<is>(Attribute $attr, :@relationship! where { .all ~~ Callable and .elems == 2 } --> Empty) is export {
    $attr.package.^add-relationship: $attr, |@relationship
}

multi trait_mod:<is>(Attribute $attr, :$relationship! (&relationship, Str :$model!, Str :$require = $model) --> Empty) is export {
    $attr.package.^add-relationship: $attr, &relationship, :$model, :$require
}

multi trait_mod:<is>(Attribute $attr, :$relationship! (Str :$column!, Str :$model!, Str :$require = $model) --> Empty) is export {
    $attr.package.^add-relationship: $attr, :$column, :$model, :$require
}

multi trait_mod:<is>(Attribute $attr, Callable :$relationship! ( @relationship! where *.elems == 2, Str :$model!, Str :$require = $model) --> Empty) {
    $attr.package.^add-relationship: $attr, |@relationship, :$model, :$require
}

# Traits to define 'phaser' methods

multi trait_mod:<is>(Method $m, :$before-create! --> Empty) {
    $m does BeforeCreate;
}

multi trait_mod:<is>(Method $m, :$after-create! --> Empty) {
    $m does AfterCreate;
}

multi trait_mod:<is>(Method $m, :$before-update! --> Empty) {
    $m does BeforeUpdate;
}

multi trait_mod:<is>(Method $m, :$after-update! --> Empty) {
    $m does AfterUpdate;
}

multi trait_mod:<is>(Method $m, :$before-delete! --> Empty) {
    $m does BeforeDelete;
}

multi trait_mod:<is>(Method $m, :$after-delete! --> Empty) {
    $m does AfterDelete;
}
