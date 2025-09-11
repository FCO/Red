# Red Versioned Models Documentation

## Overview

Red now supports versioned models through the `Red::ModelRegistry` module. This addresses the migration issue by providing a way to manage multiple versions of the same logical model without running into Raku's redeclaration errors.

## The Problem

The original issue was that Raku doesn't allow multiple declarations of the same symbol with different versions in the same compilation unit:

```raku
model User:ver<0.1> { ... }
model User:ver<0.2> { ... }  # ← Error: Redeclaration of symbol 'User'
```

## The Solutions

### Solution 1: One File Per Version (Recommended)

**When model versions are declared in different files**, you can use Raku's native `:ver<>` syntax:

```raku
# File: lib/User-v1.rakumod
use Red;
model User:ver<1.0> {
    has Int $.id is serial;
    has Str $.name is column;
    has Int $.age is column;
}

# File: lib/User-v2.rakumod  
use Red;
model User:ver<2.0> {
    has Int $.id is serial;
    has Str $.name is column;
    has Str $.email is column;
    has Int $.age is column;
}

# Usage in migration code:
use Red::ModelRegistry;

my $user-v1 = require-model-version('User', '1.0');
my $user-v2 = require-model-version('User', '2.0');

# Setup migration between versions
$user-v2.^migrate(from => $user-v1);
```

### Solution 2: Different Model Names with Trait Registration

When you need all versions in the same file or want explicit different names:

```raku
use Red "experimental migrations";
use Red::ModelRegistry;

# Define different versions using different names and register with traits
model UserV01 is model-version('User:0.1') {
    has Str $.name is column;
    has Int $.age is column;
}

model UserV02 is model-version('User:0.2') {
    has Str $.name is column;
    has Str $.full-name is column;
    has Int $.age is column;
}

# Alternative syntax using hash notation
model UserV03 is model-version({ name => 'User', version => '0.3' }) {
    has Str $.name is column;
    has Str $.full-name is column;
    has Str $.email is column;
    has Int $.age is column;
}

# Retrieve models by logical name and version
my $v01 = get-model-version('User', '0.1');
my $v02 = get-model-version('User', '0.2');

# Setup migrations between versions
$v02.^migration: {
    .full-name = "{ .name } (migrated from v0.1)"
};
```

## API Reference

### Registration Functions

- `register-model-version($logical-name, $version, $model-class)` - Register a model as a version
- `get-model-version($logical-name, $version)` - Retrieve a specific model version
- `list-model-versions($logical-name)` - List all versions of a logical model
- `get-latest-model-version($logical-name)` - Get the latest version of a model
- `list-all-models()` - List all registered logical models
- `require-model-version($model-name, $version)` - Load a versioned model from separate file
- `compare-model-versions($from-model, $to-model)` - Compare two versions for migration analysis

### Trait Registration Options

#### Native Raku Version Syntax (Recommended for separate files)

```raku
# In separate files
model User:ver<1.0> { ... }    # String version
model User:ver<2.0> { ... }    # String version
```

#### Custom Logical Names (For same-file usage)

```raku
model UserV1 is model-version('User:1.0') { ... }
model UserV2 is model-version({ name => 'User', version => '2.0' }) { ... }
```

### Migration Support

The versioned models work seamlessly with Red's existing migration infrastructure:

```raku
# Setup migration from v0.1 to v0.2
$v02.^migration: {
    .full-name = "{ .name } (migrated)"
};

# The migration system tracks changes
$v02.^dump-migrations;
```

## Benefits

1. **No Redeclaration Errors** - Uses different files or physical model names
2. **Native Raku Syntax** - Can use natural `:ver<>` syntax with separate files  
3. **Logical Versioning** - Maps to logical model versions
4. **Red Integration** - Works with existing Red migration infrastructure
5. **Flexibility** - Supports complex migration scenarios
6. **Testing** - Easy to test different model versions
7. **Modular Organization** - One file per version for better organization

## File Organization Patterns

### Recommended: One File Per Version

```
lib/
├── Models/
│   ├── User-v1.rakumod    # User:ver<1.0>
│   ├── User-v2.rakumod    # User:ver<2.0>
│   └── User-v3.rakumod    # User:ver<3.0>
└── Migrations/
    ├── user-v1-to-v2.raku
    └── user-v2-to-v3.raku
```

### Alternative: Versioned Directories

```
lib/
├── Models/
│   ├── v1/
│   │   └── User.rakumod   # User:ver<1.0>
│   ├── v2/  
│   │   └── User.rakumod   # User:ver<2.0>
│   └── v3/
│       └── User.rakumod   # User:ver<3.0>
└── Migrations/
    └── ...
```

## Example Usage

### File-per-Version Pattern (Recommended)

See `examples/versioned-models-file-per-version.raku` for a comprehensive demonstration of the file-per-version approach using native `:ver<>` syntax.

### Traditional Pattern  

See `t/95-versioned-migration-solution.rakutest` for a comprehensive example demonstrating:

- Model registration across multiple versions
- Migration setup between versions
- Instance creation and usage
- Integration with Red's migration system

### Testing

See `t/96-versioned-models-native-syntax.rakutest` for tests demonstrating the native `:ver<>` syntax support.

## Future Enhancements

This foundation enables future enhancements such as:

- Automatic migration path discovery between file-based versions
- Schema diffing between versions using model introspection
- CLI tooling for generating version file templates
- Integration with package managers for version dependencies
- Automated schema validation across version chains