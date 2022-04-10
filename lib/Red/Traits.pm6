use Red::Column;
use Red::Attr::Column;
use Red::ResultSeq;
use Red::Phaser;
unit module Red::Traits;

=head2 Red::Traits

=head3 is temp

#| This trait marks the corresponding table of the
#| model as TEMPORARY (so it only exists for the time
#| of Red being connected to the database).
multi trait_mod:<is>(Mu:U $model, Bool :$temp! --> Empty) {
    $model.^temp = True;
}

=head3 is rs-class

#| This trait defines the name of the class to be used as
#| ResultSet to this model.
multi trait_mod:<is>(Mu:U $model, Str:D :$rs-class! --> Empty) {
    trait_mod:<is>($model, :rs-class(::($rs-class)))
}

=head3 is rs-class

#| This trait defines the class to be used as ResultSet to this model.
multi trait_mod:<is>(Mu:U $model, Mu:U :$rs-class! --> Empty) {
    die "{$rs-class.^name} should do the Red::ResultSeq role" unless $rs-class ~~ Red::ResultSeq;
    my role RSClass[Mu:U $rclass] { method rs-class(|) { $rclass<> } }
    $model.HOW does RSClass[$rs-class];
}

=head3 is nullable

#| This trait configures all model attributes (columns) to be NULLABLE by default, when used as `is nullable`.
#| Without this trait applied, default for every attribute (column) is NOT NULL,
#| though it can be stated explicitly with writing `is !nullable` for the model.
#| Defaults can be overridden using `is nullable` or `is !nullable` for the attribute (column) itself.
multi trait_mod:<is>(Mu:U $model, Bool :$nullable! --> Empty) {
    $model.HOW does role :: { method default-nullable(|) { $nullable } }
}

=head3 is column

#| Defines the attribute as a column without any custom configuration.
multi trait_mod:<is>(Attribute $attr, Bool :$column! --> Empty) is export {
    trait_mod:<is>($attr, :column{}) if $column
}

=head3 is column

#| Defines the attribute as a column receiving a string to be used as the column name.
multi trait_mod:<is>(Attribute $attr, Str :$column! --> Empty) is export {
    trait_mod:<is>($attr, :column{:name($column)}) if $column
}

=head3 is unique

#| This trait marks an attribute (column) as UNIQUE.
multi trait_mod:<is>(Attribute $attr, Bool :$unique! where $_ == True --> Empty) is export {
    trait_mod:<is>($attr, :column{:unique})
}

=head3 is unique

#| This trait marks an attribute (column) as UNIQUE receiving data to ve used on column definition.
multi trait_mod:<is>(Attribute $attr, :$unique! --> Empty) is export {
    trait_mod:<is>($attr, :column{:$unique})
}

=head3 is id

#| This trait marks an attribute (column) as SQL PRIMARY KEY.
multi trait_mod:<is>(Attribute $attr, Bool :$id! where $_ == True --> Empty) is export {
    trait_mod:<is>($attr, :column{:id, :!nullable})
}

=head3 is serial

#| This trait marks an attribute (column) as SQL PRIMARY KEY with SERIAL data type, which
#| means it auto-increments on each insertion.
multi trait_mod:<is>(Attribute $attr, Bool :$serial! where $_ == True --> Empty) is export {
    trait_mod:<is>($attr, :column{:id, :!nullable, :auto-increment})
}

=head3 is column

#| A generic trait used for customizing a column. It accepts a hash of Bool keys.
#| Possible values include:
#| * id - marks a column PRIMARY KEY
#| * auto-increment - marks a column AUTO INCREMENT
#| * nullable - marks a column as NULLABLE
#| * TBD
multi trait_mod:<is>(Attribute $attr, :%column! --> Empty) is export {
    if %column<references>:exists && (%column{<model-name model-type>.none}:exists) {
        die "On Red:api<2> references must declaire :model-name (or :model-type) and the references block must receive the model as reference"
    }
    $attr does Red::Attr::Column(%column);
}

multi trait_mod:<is>(Attribute $attr, :&referencing! --> Empty) is export {
    die 'On Red:api<2> ":model" is required on "is referencing"'
}

=head3 is referencing

#| Trait that defines a reference receiving a code block, a model name, optional require string and nullable.
multi trait_mod:<is>(Attribute $attr, :$referencing! (&referencing!, Str :$model!, Str :$require = $model, Bool :$nullable = True ) --> Empty) is export {
    trait_mod:<is>($attr, :column{ :$nullable, :references(&referencing), model-name  => $model, :$require })
}

=head3 is referencing

#| Trait that defines a reference receiving a model name, a column name, and optional require string and nulabble.
multi trait_mod:<is>(Attribute $attr, :$referencing! (Str :$model!, Str :$column!, Str :$require = $model, Bool :$nullable = True ) --> Empty) is export {
    trait_mod:<is>($attr, :column{ :$nullable, model-name => $model, column-name => $column, :$require })
}


=head3 is referencing

#| Trait that defines a reference receiving a code block, a model type object and an optional nullable.
multi trait_mod:<is>(Attribute $attr, :$referencing! (&referencing!, Mu:U :$model!, Bool :$nullable = True ) --> Empty) is export {
    $model.^add_role: Red::Model;
    trait_mod:<is>($attr, :column{ :$nullable, :references(&referencing), model-type  => $model })
}

=head3 is referencing

#| Trait that defines a reference receiving a model type object, a column name, and optional nulabble.
multi trait_mod:<is>(Attribute $attr, :$referencing! (Mu:U :$model!, Str :$column!, Bool :$nullable = True ) --> Empty) is export {
    trait_mod:<is>($attr, :column{ :$nullable, model-type => $model, column-name => $column })
}

=head3 is table

#| This trait allows setting a custom name for a table corresponding to a model.
#| For example, `model MyModel is table<custom_table_name> {}` will use `custom_table_name`
#| as the name of the underlying database table.
multi trait_mod:<is>(Mu:U $model, Str :$table! is copy where .chars > 0 --> Empty) {
    $model.HOW.^attributes.first({ .name eq '$!table' }).set_value($model.HOW, $table)
}

=head3 is relationship

#| Trait that defines a relationship receiving a code block.
multi trait_mod:<is>(Attribute $attr, :&relationship! --> Empty) is export {
    $attr.package.^add-relationship: $attr, &relationship
}

=head3 is relationship

#| DEPRECATED: Trait that defines a relationship receiving 2 code blocks.
multi trait_mod:<is>(Attribute $attr, :@relationship! where { .all ~~ Callable and .elems == 2 } --> Empty) is DEPRECATED is export {
    $attr.package.^add-relationship: $attr, |@relationship
}

=head3 is relationship

#| Trait that defines a relationship receiving a code block, a model name, and opitionaly require string, optional, no-prefetch and has-one.
multi trait_mod:<is>(Attribute $attr, :$relationship! (&relationship, Str :$model, Str :$require = $model, Bool :$optional, Bool :$no-prefetch, Bool :$has-one) --> Empty) is export {
    die "Please, use the has-one experimental feature (use Red <has-one>) to allow using it on relationships"
    	if $has-one && !%Red::experimentals<has-one>;
    $attr.package.^add-relationship: $attr, &relationship, |(:$model with $model), |(:$require with $require), :$optional, :$no-prefetch, |(:$has-one if $has-one)
}

=head3 is relationship

#| Trait that defines a relationship receiving a code block, a model type object, and opitionaly require string, optional, no-prefetch and has-one.
multi trait_mod:<is>(Attribute $attr, :$relationship! (&relationship, Mu:U :$model!, Bool :$optional, Bool :$no-prefetch, Bool :$has-one) --> Empty) is export {
    die "Please, use the has-one experimental feature (use Red <has-one>) to allow using it on relationships"
        if $has-one && !%Red::experimentals<has-one>;
    $attr.package.^add-relationship: $attr, &relationship, :model-type($model), :$optional, :$no-prefetch, |(:$has-one if $has-one)
}

=head3 is relationship

#| Trait that defines a relationship receiving a column name, a model name and opitionaly a require, optional, no-prefetch and has-one.
multi trait_mod:<is>(Attribute $attr, :$relationship! (Str :$column!, Str :$model!, Str :$require = $model, Bool :$optional, Bool :$no-prefetch, Bool :$has-one) --> Empty) is export {
    die "Please, use the has-one experimental feature (use Red <has-one>) to allow using it on relationships"
    	if $has-one && !%Red::experimentals<has-one>;
    $attr.package.^add-relationship: $attr, :$column, :$model, :$require, :$optional, :$no-prefetch, |(:$has-one if $has-one)
}

multi trait_mod:<is>(Attribute $attr, Callable :$relationship! ( @relationship! where *.elems == 2, Str :$model!, Str :$require = $model, Bool :$optional, Bool :$no-prefetch, Bool :$has-one) --> Empty) {
    die "Please, use the has-one experimental feature (use Red <has-one>) to allow using it on relationships"
    	if $has-one && !%Red::experimentals<has-one>;
    $attr.package.^add-relationship: $attr, |@relationship, :$model, :$require, :$optional, :$no-prefetch, |(:$has-one if $has-one)
}

=head3 is before-create

#| Trait to define a phaser to run before create a new record
multi trait_mod:<is>(Method $m, :$before-create! --> Empty) {
    $m does BeforeCreate;
}

=head3 is after-create

#| Trait to define a phaser to run after create a new record
multi trait_mod:<is>(Method $m, :$after-create! --> Empty) {
    $m does AfterCreate;
}

=head3 is before-update

#| Trait to define a phaser to run before update a record
multi trait_mod:<is>(Method $m, :$before-update! --> Empty) {
    $m does BeforeUpdate;
}

=head3 is after-update

#| Trait to define a phaser to run after update record
multi trait_mod:<is>(Method $m, :$after-update! --> Empty) {
    $m does AfterUpdate;
}

=head3 is before-delete

#| Trait to define a phaser to run before delete a record
multi trait_mod:<is>(Method $m, :$before-delete! --> Empty) {
    $m does BeforeDelete;
}

=head3 is after-delete

#| Trait to define a phaser to run after delete a record
multi trait_mod:<is>(Method $m, :$after-delete! --> Empty) {
    $m does AfterDelete;
}

=head is sub-module

#| Trait to transform subset into sub-model
multi trait_mod:<is>($subset where { .HOW ~~ Metamodel::SubsetHOW }, Bool :$sub-model) {
    use MetamodelX::Red::SubModelHOW;
    $subset.HOW does MetamodelX::Red::SubModelHOW;
    $subset
}
