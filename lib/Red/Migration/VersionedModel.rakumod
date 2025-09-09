use v6;
use Red::ModelRegistry;

#| Enhanced migration support for versioned models.
unit class Red::Migration::VersionedModel;

my $registry = Red::ModelRegistry.new;

#| Register a model as a specific version of a logical model
method register-model-version(Str $logical-name, Version $version, Mu $model-class) {
    $registry.register-model($logical-name, $version, $model-class);
    
    # Add methods to the model metaclass to get logical name and version
    $model-class.HOW.^add_method('logical-name', method (\model) { $logical-name });
    $model-class.HOW.^add_method('logical-version', method (\model) { $version });
    
    # Enhanced migration method
    $model-class.HOW.^add_method('migrate-from-version', method (\model, Version $from-version, &migration-block?) {
        my $from-model = $registry.get-model($logical-name, $from-version);
        die "No model found for {$logical-name} version {$from-version}" unless $from-model;
        
        if &migration-block {
            # Apply migration logic using existing Red migration infrastructure
            model.^migration(&migration-block);
            model.^migrate(:from($from-model));
        }
        
        "Migration setup from {$logical-name} v{$from-version} to v{$version}"
    });
    
    # Recompose the model
    $model-class.HOW.^compose;
}

#| Get a model by logical name and version
method get-model(Str $logical-name, Version $version) {
    $registry.get-model($logical-name, $version)
}

#| Get all versions of a logical model
method get-versions(Str $logical-name) {
    $registry.get-model-versions($logical-name)
}

#| List all logical models
method list-logical-models() {
    $registry.list-models()
}

# Create a singleton instance
my $instance = Red::Migration::VersionedModel.new;

# Export convenience functions
sub register-model-version(Str $logical-name, $version, $model-class) is export {
    $instance.register-model-version($logical-name, Version.new($version), $model-class)
}

sub get-model-version(Str $logical-name, $version) is export {
    $instance.get-model($logical-name, Version.new($version))
}

sub list-model-versions(Str $logical-name) is export {
    $instance.get-versions($logical-name)
}