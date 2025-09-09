use v6;
use Red::ModelRegistry;

#| A role that provides versioned model support by extending the model declaration system.
unit role MetamodelX::Red::VersionedModel;

my $registry = Red::ModelRegistry.new;

#| Enhanced model declaration that supports versioned models
method new_type(|c) {
    my $type = callsame;
    
    # Check if this is a versioned model
    if $type.^ver {
        my $name = $type.^name.subst(/':ver<' .* '>'$/, '');
        my $version = $type.^ver;
        
        # Register this version in the registry
        $registry.register-model($name, $version, $type);
        
        # Store the base name for later reference
        $type.^set_name($name ~ ':ver<' ~ $version ~ '>');
    }
    
    $type
}

#| Get a specific version of a model by name and version
method get-versioned-model(Str $name, Version $version) {
    $registry.get-model($name, $version)
}

#| Get all versions of a model
method get-model-versions(Str $name) {
    $registry.get-model-versions($name)
}

#| Get the latest version of a model
method get-latest-model(Str $name) {
    $registry.get-latest-model($name)
}

#| Check if a versioned model exists
method has-versioned-model(Str $name, Version $version) {
    $registry.has-model($name, $version)
}

#| List all registered versioned models
method list-versioned-models() {
    $registry.list-models()
}

#| Get registry for external access
method model-registry() {
    $registry
}