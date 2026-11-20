use v6;

=head2 MetamodelX::Red::GlobalNotifiable

#| Metamodel role mixed into the HOW of models declared with C<is global-notifiable>.
unit role MetamodelX::Red::GlobalNotifiable;

#| Inserts on this model are published through the driver's notification backend.
method global-notifiable(Mu:U --> Bool:D) { True }

#| SQL column names used to identify a row in a global notification.
method global-notification-columns(Mu:U \model --> Array:D) {
    model.^id.map(*.column.name).Array
}

#| Attribute names used to fetch the row back with C<^find>.
method global-notification-ids(Mu:U \model --> Array:D) {
    model.^id.map(*.column.attr-name).Array
}
