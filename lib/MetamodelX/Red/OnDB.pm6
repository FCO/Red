use nqp;
use Red::Attr::Column;

=head2 MetamodelX::Red::OnDB

unit role MetamodelX::Red::OnDB;

has $!is-on-db-attr;

method is-on-db-attr(|) {
    $!is-on-db-attr;
}

sub is-on-db-attr-build(|){
    False
}

method set-helper-attrs(Mu \type) {
    $!is-on-db-attr = Attribute.new: :name<%!___IS_ON_DB___>, :package(type), :type(Bool), :!has_accessor;
    $!is-on-db-attr.set_build: &is-on-db-attr-build;
    type.^add_attribute: $!is-on-db-attr;
}

#| Checks if the instance of model has a record in the database or not.
#| For example, `Person.^create(...).^is-on-db` returns True, because `^create` was called,
#| but `Person.new(...).^is-on-db` will return False, because the created object does not have
#| a representation in the database without calls to `^create` or `^save` done.
multi method is-on-db(\instance) {
    $!is-on-db-attr.get_value(instance)
}

#| Sets that that object is on DB
multi method saved-on-db(\instance) {
    $!is-on-db-attr.get_value(instance) = True
}
