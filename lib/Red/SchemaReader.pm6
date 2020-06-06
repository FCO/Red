#| Base role to schema readers
#| used to read DB Schema
unit role Red::SchemaReader;

method tables-names                             { ... }
method indexes-of($table)                       { ... }
method table-definition($table)                 { ... }
method table-definition-from-create-table($sql) { ... }
