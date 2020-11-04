# Experimental features

* `is-handling`

  make it possible to use the traint `is handling` that "exports" the given `ResultSeq`'s methods to the model itself
  
* `migrations`

  make it possible to test the prototype of the migration feature
  
* `formaters`

  make it possible to change the rule of creation of the names of tables and columns
  
* `shortname`

  make Red use the `shortname` of the model to create the table's name instead of the full name

* `has-one`

  creeates a new option to relationship: `has-one`. For more details: https://github.com/FCO/Red/issues/452

## How to use experimental feartures?

when `use`ing Red, pass a list of wanted experimental features, For example:

```raku
use Red <is-handling migrations formaters shortname has-one>;
```
