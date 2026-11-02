Red::Migration::Artifact
------------------------

class Red::Migration::Artifact::Manifest
----------------------------------------

Typed configuration root for a version manifest, including ancestry and driver metadata.

### method artifact-data

```raku
method artifact-data() returns Hash
```

Return defined manifest fields as a metadata hash, including identity, ancestry and integrity fingerprints. Retain legacy population metadata only for format rejection.

class Red::Migration::Artifact::Operations
------------------------------------------

Typed configuration root for the portable structural changes recorded by a version.

### method artifact-data

```raku
method artifact-data() returns Array
```

Return the ordered portable schema changes used to validate and rebase this version.

class Red::Migration::Artifact::Overrides
-----------------------------------------

Typed configuration root for explicitly supplied SQL and its inverse policy for one driver.

### method artifact-data

```raku
method artifact-data() returns Hash
```

Return the manual SQL selection, inverse availability and review reason for one driver.

class Red::Migration::Artifact::Schema
--------------------------------------

Typed configuration root that reconstructs historical Red::Cli::Table objects.

### method artifact-data

```raku
method artifact-data() returns Array
```

Return the typed historical table objects constructed by the schema configuration.

### sub builders

```raku
sub builders(
    Str $kind
) returns Mu
```

Create isolated typed configuration builders for an artifact kind. Artifact loading must not replace the application Configuration singleton.

### sub literal

```raku
sub literal(
    $value,
    Int $depth = 0,
    Bool :$itemize = Bool::False
) returns Str
```

Serialize nested metadata deterministically as readable Raku expressions. Itemize hashes inside positional collections so their pairs do not flatten into the surrounding array.

### sub artifact-source

```raku
sub artifact-source(
    Str $kind,
    $data
) returns Str
```

Generate a trusted executable config artifact for a manifest, operations or driver overrides, with deterministic key ordering and typed builders.

