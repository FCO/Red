use Red::Column;
use Red::Attr::Column;
use Red::ResultSeq;
unit module Red::Traits;

multi trait_mod:<is>(Mu:U $model, Str:D :$rs-class!) {
    trait_mod:<is>($model, :rs-class(::($rs-class)))
}

multi trait_mod:<is>(Mu:U $model, Mu:U :$rs-class!) {
    die "{$rs-class.^name} should do the Red::ResultSeq role" unless $rs-class ~~ Red::ResultSeq;
    $model.HOW does role :: { method rs-class(|) { $rs-class<> } }
}

multi trait_mod:<is>(Mu:U $model, Bool :$nullable!) {
    $model.HOW does role :: { method default-nullable(|) { $nullable } }
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
    my $class = $attr.package;
    my $obj = Red::Column.new: |%column, :$attr, :$class;
    $attr does Red::Attr::Column($obj);
}

multi trait_mod:<is>(Attribute $attr, :&referencing!) is export {
    trait_mod:<is>($attr, :column{ :nullable, :references(&referencing) })
}

multi trait_mod:<is>(Attribute $attr, :$referencing! (:$model!, :$column! )) is export {
    trait_mod:<is>($attr, :column{ :nullable, model-name => $model, column-name => $column })
}

multi trait_mod:<is>(Mu:U $model, Str :$table! where .chars > 0) {
    $model.HOW does role :: {
        method table(|) { $table<> }
    }
}

multi trait_mod:<is>(Attribute $attr, :%relationship! (Str :$column!, Str :$model!, Str :$require = $model)) is export {
    my &rel := { ."$column"() }
    trait_mod:<is>($attr, :relationship(&rel, :$model, :$require))
}

multi trait_mod:<is>(Attribute $attr, :@relationship! (&rel, Str :$model!, Str :$require = $model)) is export {
    my &relationship := {
        try require ::($require);
        my Any:U $type = do if $attr.type ~~ Positional {
            ::($model)
        } else {
            $attr.package
        }

        rel $type
    }
    trait_mod:<is>($attr, :&relationship)
}

multi trait_mod:<is>(Attribute $attr, :&relationship!) is export {
    $attr.package.^add-relationship: $attr, &relationship
}

multi trait_mod:<is>(Attribute $attr, Callable :@relationship! where *.elems == 2) is export {
    $attr.package.^add-relationship: $attr, |@relationship
}

multi trait_mod:<is>(Attribute $attr, :$relationship! (&relationship, :$model!)) is export {
    $attr.package.^add-relationship: $attr, &relationship, :$model
}

multi trait_mod:<is>(Attribute $attr, Callable :$relationship ( @relationship! where *.elems == 2, :$model!)) {
    $attr.package.^add-relationship: $attr, |@relationship, :$model
}
