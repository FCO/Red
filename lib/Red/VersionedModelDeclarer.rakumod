use v6;
use Red::ModelRegistry;
use MetamodelX::Red::Model;

#| A helper that provides versioned model declaration support.
unit class Red::VersionedModelDeclarer;

my $registry = Red::ModelRegistry.new;

#| Declare a versioned model 
method declare-versioned-model(Str $name, Version $version, &block) {
    # Create a unique internal name to avoid redeclaration errors
    my $internal-name = $name ~ '_v' ~ $version.Str.subst('.', '_', :g);
    
    # Create the model class dynamically
    my $model-type = Metamodel::ClassHOW.new_type(:name($internal-name));
    
    # Apply Red::Model metaclass behaviors
    $model-type does Red::Model;
    
    # Set the version
    $model-type.^set_ver($version);
    
    # Apply the user-defined block to set up the model
    $model-type.^compose;
    
    # Register in our versioned model registry
    $registry.register-model($name, $version, $model-type);
    
    # Return the model type
    $model-type
}

#| Get a versioned model
method get-model(Str $name, Version $version) {
    $registry.get-model($name, $version)
}

#| Get the registry
method registry() {
    $registry
}

# Export function to declare versioned models
sub vmodel($name, $version, &block) is export {
    Red::VersionedModelDeclarer.declare-versioned-model($name, Version.new($version), &block)
}