# Model access and temporary projection storage

Temporary projection storage models retain their own metadata and captured expressions.
Their parameterized `ResultSeq` classes are composed when first requested through the
metamodel, `.^all`, or the model's `ResultSeq` package symbol. Declared models continue
to initialize their query classes when defined. Chained projections can use the storage
metadata directly while building SQL expressions.
The shared storage parent supplies generic model methods. Column metadata, helper
attributes, captured expressions, row values and dirty flags retain their individual owners.

`raku -Ilib tools/benchmark-model-access.raku` measures loading and reading models,
repeated field reads, and field writes without saving. It uses an in-memory SQLite
database, checks the results, warms each task, alternates task order between rounds,
and emits JSON samples. Use `--rows`, `--load-iterations`, `--access-iterations` and
`--rounds` to control the workload. Database setup and module compilation are excluded.
