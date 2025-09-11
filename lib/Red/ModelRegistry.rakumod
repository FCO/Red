use v6;

#| A registry for versioned models that allows multiple versions of the same model to coexist.
unit class Red::ModelRegistry;

# Global registry for versioned models
my %model-registry;

#| Register a model with its version
method register-model(Str $name, $version, Mu $model-class) {
    %model-registry{$name}{~$version} = $model-class;
}

#| Get a specific version of a model
method get-model(Str $name, $version) {
    %model-registry{$name}{~$version}
}

#| Get all versions of a model
method get-model-versions(Str $name) {
    %model-registry{$name} // %()
}

#| Get the latest version of a model
method get-latest-model(Str $name) {
    my %versions = %model-registry{$name} // return Nil;
    return Nil unless %versions;
    
    # Sort versions and get the latest
    my $latest-version = %versions.keys.sort({ Version.new($_) }).tail;
    %versions{$latest-version}
}

#| Check if a model version exists
method has-model(Str $name, $version) {
    so %model-registry{$name}{~$version}
}

#| List all registered models
method list-models() {
    %model-registry.keys
}

#| Get all registered model-version combinations
method list-all-model-versions() {
    my @results;
    for %model-registry.kv -> $name, %versions {
        for %versions.kv -> $version, $model {
            @results.push: { name => $name, version => $version, model => $model }
        }
    }
    @results
}

# Singleton instance for global use
my $global-registry = Red::ModelRegistry.new;

# Export convenience functions
sub register-model-version(Str $logical-name, $version, $model-class) is export {
    $global-registry.register-model($logical-name, $version, $model-class)
}

sub get-model-version(Str $logical-name, $version) is export {
    $global-registry.get-model($logical-name, $version)
}

sub list-model-versions(Str $logical-name) is export {
    $global-registry.get-model-versions($logical-name)
}

sub get-latest-model-version(Str $logical-name) is export {
    $global-registry.get-latest-model($logical-name)
}

sub list-all-models() is export {
    $global-registry.list-models()
}

#| Load a versioned model from a separate file using require
#| Supports predictable file locations without explicit registration
sub require-model-version(Str $model-name, Str $version) is export {
    # Try native Raku module loading first
    my $module-name = "{$model-name}:ver<{$version}>";
    try {
        return require ::($module-name);
    }
    
    # Try predictable file locations
    my @search-paths = (
        "{$model-name}-v{$version}",
        "Models/{$model-name}-v{$version}",
        "lib/{$model-name}-v{$version}", 
        "lib/Models/{$model-name}-v{$version}",
        "{$model-name}/v{$version}",
        "Models/{$model-name}/v{$version}",
        "lib/{$model-name}/v{$version}",
        "lib/Models/{$model-name}/v{$version}"
    );
    
    for @search-paths -> $path {
        try {
            my $result = require ::("{$path}");
            if $result.^can('HOW') && $result.^name ~~ /:ver/ {
                # Register it for future use
                my $logical-name = $result.^name;
                $logical-name ~~ s/ ':ver<' .* '>' //;
                register-model-version($logical-name, $version, $result);
                return $result;
            }
        }
    }
    
    # Fallback to looking in registry if require fails
    return get-model-version($model-name, $version);
}

#| Compare two model versions for migration planning
sub compare-model-versions(Mu $from-model, Mu $to-model) is export {
    # This is a placeholder for future schema comparison functionality
    # Could analyze attributes, relationships, constraints, etc.
    return { 
        from => $from-model.^name, 
        to => $to-model.^name,
        # Future: detailed diff analysis
    };
}