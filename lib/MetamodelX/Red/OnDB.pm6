use nqp;
use Red::Attr::Column;
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

#| Is that object on DB?
multi method is-on-db(\instance) {
    $!is-on-db-attr.get_value(instance)
}

#| Sets that that object is on DB
multi method saved-on-db(\instance) {
    $!is-on-db-attr.get_value(instance) = True
}

