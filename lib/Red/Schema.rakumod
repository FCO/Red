use Red::Do;
use Red::DB;
use Red::Runtime::Configuration;
unit class Red::Schema;

proto sub schema(|) { * }

#| Build a schema from the configured models without opening the configured database.
multi sub schema() is export is default {
    my $settings = runtime-settings();
    ::?CLASS.new($settings.defined ?? $settings.model-types !! [])
}

multi sub schema(+@models) is export {
    ::?CLASS.new: @models
}

multi sub schema(*%models) is export {
    ::?CLASS.new: %models
}

has %.models;

multi method new(@models) {
    my %models = @models.map: {
        do if $_ ~~ Str {
            require ::($_);
            $_ => ::($_)
        } else {
            .^name => $_
        }
    }
    self.bless: :%models
}

multi method new(%model-alias) {
    my %models = %model-alias.kv.map: -> $alias, $model {
        do if $model ~~ Str {
            require ::($model);
            $alias => ::($model)
        } else {
            $alias => $model
        }
    }
    self.bless: :%models
}


method FALLBACK(Str $name) {
    $.model($name);
}

method model(Str $name) {
    do if %!models{ $name }:exists {
        %!models{ $name }
    } else {
        fail "Model '$name' not found on schema"
    }
}

# TODO: For tests only, please make it right
method drop {
    for %!models.values {
        my $drop = "DROP TABLE IF EXISTS { get-RED-DB.table-name-wrapper: .^table } { "CASCADE" if get-RED-DB.should-drop-cascade }";
        get-RED-DB.execute($drop);
        #.emit: $drop
    }
    self
}

method create(:$where) {
    red-do (:$where with $where), :transaction, {
        |.create-schema(%!models);
    }
    self
}

#| Return development DDL without executing it.
method plan(:$where, Bool :$allow-destructive = True --> Array) {
    self!migration-manager($where // get-RED-DB).plan(:$allow-destructive)
}

#| Synchronize selected models without creating versioned migrations.
method update(:$where, Bool :$allow-destructive = False) {
    self!migration-manager($where // get-RED-DB).sync(:$allow-destructive);
    self
}

method !migration-manager($driver) {
    require ::('Red::Migration::Configuration');
    require ::('Red::Migration::Manager');
    ::('Red::Migration::Manager').new(:config(::('Red::Migration::Configuration').new(
        :models(%!models.values.Array), :connections{ default => $driver })))
}
