# Experimental features

* `migrations`

  make it possible to test the prototype of the migration feature
  
* `formatters`

  make it possible to change the rule of creation of the names of tables and columns
  
* `shortname`

  make Red use the `shortname` of the model to create the table's name instead of the full name

* `supply`

  adds a `.^supply` meta-method on the model returning a `Supply` of rows

## How to use experimental feartures?

when `use`ing Red, pass a list of wanted experimental features, For example:

```raku
use Red <migrations formatters shortname supply>;
```

## Promoted features

The following features were promoted to stable and no longer need to be enabled.
For backwards compatibility, `use Red <has-one refreshable is-handling>` still
compiles, but the flags are now no-ops:

* `is-handling` — see `is handling` trait (exports `ResultSeq` methods to the model itself)
* `has-one` — see [relationships](relationship.md)
* `refreshable` — adds `.^refresh` on model instances (accepts a list of column
  names or nothing at all, and "refreshes" those columns — or all columns if no
  list was defined — with the actual data from the database)

