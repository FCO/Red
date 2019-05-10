use Red::Column;
use Red::Attr::Column;
use Red::ResultSeq;
use Red::Phaser;
unit module Red::Traits;

multi trait_mod:<is>(Mu:U $model, Bool :$temp!) {
    $model.^temp = True;
}

multi trait_mod:<is>(Mu:U $model, Str:D :$rs-class!) {
    trait_mod:<is>($model, :rs-class(::($rs-class)))
}

multi trait_mod:<is>(Mu:U $model, Mu:U :$rs-class!) {
    die "{$rs-class.^name} should do the Red::ResultSeq role" unless $rs-class ~~ Red::ResultSeq;
    my role RSClass[Mu:U $rclass] { method rs-class(|) { $rclass<> } }
    $model.HOW does RSClass[$rs-class];
}

multi trait_mod:<is>(Mu:U $model, Bool :$nullable!) {
    $model.^default-nullable = True
}

multi trait_mod:<is>(Attribute $attr, Bool :$column!) is export {
    trait_mod:<is>($attr, :column{}) if $column
}

multi trait_mod:<is>(Attribute $attr, Str :$column!) is export {
    trait_mod:<is>($attr, :column{:name($column)}) if $column
}

multi trait_mod:<is>(Attribute $attr, Bool :$id! where $_ == True) is export {
    trait_mod:<is>($attr, :column{:id, :!nullable})
}

multi trait_mod:<is>(Attribute $attr, Bool :$serial! where $_ == True) is export {
    trait_mod:<is>($attr, :column{:id, :!nullable, :auto-increment})
}

multi trait_mod:<is>(Attribute $attr, :%column!) is export {
    $attr does Red::Attr::Column(%column);
}

multi trait_mod:<is>(Attribute $attr, :&referencing! ) is export {
    trait_mod:<is>($attr, :column{ :nullable, :references(&referencing) })
}

multi trait_mod:<is>(Attribute $attr, :$referencing! (&referencing!, Str :$model!, Str :$require = $model )) is export {
    trait_mod:<is>($attr, :column{ :nullable, :references(&referencing), model-name  => $model, :$require })
}

multi trait_mod:<is>(Attribute $attr, :$referencing! (Str :$model!, Str :$column!, Str :$require = $model )) is export {
    trait_mod:<is>($attr, :column{ :nullable, model-name => $model, column-name => $column, :$require })
}

multi trait_mod:<is>(Mu:U $model, Str :$table! where .chars > 0) {
    $model.HOW.^attributes.first({ .name eq '$!table' }).set_value($model.HOW, $table)
}

multi trait_mod:<is>(Attribute $attr, :&relationship!) is export {
    $attr.package.^add-relationship: $attr, &relationship
}

multi trait_mod:<is>(Attribute $attr, :@relationship! where { .all ~~ Callable and .elems == 2 }) is export {
    $attr.package.^add-relationship: $attr, |@relationship
}

multi trait_mod:<is>(Attribute $attr, :$relationship! (&relationship, Str :$model!, Str :$require = $model)) is export {
    $attr.package.^add-relationship: $attr, &relationship, :$model, :$require
}

multi trait_mod:<is>(Attribute $attr, :$relationship! (Str :$column!, Str :$model!, Str :$require = $model)) is export {
    $attr.package.^add-relationship: $attr, :$column, :$model, :$require
}

multi trait_mod:<is>(Attribute $attr, Callable :$relationship! ( @relationship! where *.elems == 2, Str :$model!, Str :$require = $model)) {
    $attr.package.^add-relationship: $attr, |@relationship, :$model, :$require
}

# Traits to define 'phaser' methods

multi trait_mod:<is>(Method $m, :$before-create!) {
    $m does BeforeCreate;
}

multi trait_mod:<is>(Method $m, :$after-create!) {
    $m does AfterCreate;
}

multi trait_mod:<is>(Method $m, :$before-update!) {
    $m does BeforeUpdate;
}

multi trait_mod:<is>(Method $m, :$after-update!) {
    $m does AfterUpdate;
}

multi trait_mod:<is>(Method $m, :$before-delete!) {
    $m does BeforeDelete;
}

multi trait_mod:<is>(Method $m, :$after-delete!) {
    $m does AfterDelete;
}
