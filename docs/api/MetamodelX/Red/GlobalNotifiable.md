MetamodelX::Red::GlobalNotifiable
---------------------------------



Metamodel role mixed into the HOW of models declared with C<is global-notifiable>.

### method global-notifiable

```raku
method global-notifiable(
    Mu:U $
) returns Bool
```

Inserts on this model are published through the driver's notification backend.

### method global-notification-columns

```raku
method global-notification-columns(
    Mu:U \model
) returns Array:D
```

SQL column names used to identify a row in a global notification.

### method global-notification-ids

```raku
method global-notification-ids(
    Mu:U \model
) returns Array:D
```

Attribute names used to fetch the row back with C<^find>.

