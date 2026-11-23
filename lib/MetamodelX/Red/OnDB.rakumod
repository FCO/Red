use nqp;
use Red::RowSecurity;
use Red::RowSecurity::Context;
use Red::Attr::Column;

=head2 MetamodelX::Red::OnDB

unit role MetamodelX::Red::OnDB;

has $!is-on-db-attr;
has $!row-context-attr;

method is-on-db-attr(|) {
    $!is-on-db-attr;
}

sub is-on-db-attr-build(|){
    False
}

method set-helper-attrs(Mu \type) {
    my %attr is Set = type.^attributes>>.name;
    $!row-context-attr = type.^attributes.first(*.name eq '$!___ROW_CONTEXT___')
        if %attr<$!___ROW_CONTEXT___>;
    $!is-on-db-attr = type.^attributes.first(*.name eq '%!___IS_ON_DB___')
        if %attr<%!___IS_ON_DB___>;
    unless %attr<$!___ROW_CONTEXT___> {
        $!row-context-attr = Attribute.new(:name<$!___ROW_CONTEXT___>, :package(type),
            :type(Map), :!has_accessor);
        type.^add_attribute($!row-context-attr);
    }
    unless %attr<%!___IS_ON_DB___> {
            $!is-on-db-attr = Attribute.new: :name<%!___IS_ON_DB___>, :package(type), :type(Bool), :!has_accessor;
            $!is-on-db-attr.set_build: &is-on-db-attr-build;
            type.^add_attribute: $!is-on-db-attr;
    }
}

#| Checks if the instance of model has a record in the database or not.
#| For example, `Person.^create(...).^is-on-db` returns True, because `^create` was called,
#| but `Person.new(...).^is-on-db` will return False, because the created object does not have
#| a representation in the database without calls to `^create` or `^save` done.
multi method is-on-db(\instance) {
    $!is-on-db-attr.get_value(instance)
}

multi method not-on-db(\instance) {
    $!is-on-db-attr.get_value(instance) = False
}

#| Sets that that object is on DB
multi method saved-on-db(\instance) {
    if row-protected(instance) {
        my $captured = $!row-context-attr.get_value(instance);
        assert-row-context($captured) if $captured.DEFINITE;
        policy-context();
        $!row-context-attr.set_value(instance, row-security-context());
    }
    $!is-on-db-attr.get_value(instance) = True
}

method check-row-context(\instance) {
    if row-protected(instance) {
        my $context = $!row-context-attr.get_value(instance);
        assert-row-context($context) if $context.DEFINITE;
    }
}
