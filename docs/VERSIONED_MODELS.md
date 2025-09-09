# Red Versioned Models Documentation

## Overview

Red now supports versioned models through the `Red::ModelRegistry` module. This addresses the migration issue by providing a way to manage multiple versions of the same logical model without running into Raku's redeclaration errors.

## The Problem

The original issue was that Raku doesn't allow multiple declarations of the same symbol with different versions:

```raku
model User:ver<0.1> { ... }
model User:ver<0.2> { ... }  # ← Error: Redeclaration of symbol 'User'
```

## The Solution

Instead of trying to use the same model name with different versions, we use different model names but register them as versions of the same logical model:

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

1. **No Redeclaration Errors** - Uses different physical model names
2. **Logical Versioning** - Maps to logical model versions
3. **Red Integration** - Works with existing Red migration infrastructure
4. **Flexibility** - Supports complex migration scenarios
5. **Testing** - Easy to test different model versions

## Example Usage

See `t/95-versioned-migration-solution.rakutest` for a comprehensive example demonstrating:

- Model registration across multiple versions
- Migration setup between versions
- Instance creation and usage
- Integration with Red's migration system

## Future Enhancements

This foundation enables future enhancements such as:

- CLI tooling for migration generation
- Automatic migration path discovery
- Schema diffing between versions