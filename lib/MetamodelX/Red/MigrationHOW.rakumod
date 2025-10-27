use v6;

=head2 MetamodelX::Red::MigrationHOW

unit class MetamodelX::Red::MigrationHOW is Metamodel::ClassHOW;

use Red::AST;
use Red::ModelRegistry;
use Red::MigrationManager;

has %.migration-spec;
has Str $.migration-name;
has $.migration-description;

#| Create a new migration class with the specified name
method new_type(:$name!, :$description) {
    my $type = callsame(:$name);
    $type.HOW.set-migration-name($name);
    $type.HOW.set-migration-description($description // "Migration: $name");
    $type
}

#| Set the migration name
method set-migration-name($name) {
    $!migration-name = $name;
}

#| Set the migration description  
method set-migration-description($description) {
    $!migration-description = $description;
}

#| Add a table specification to the migration
method add-table($table-name, %table-spec) {
    %!migration-spec<tables>{$table-name} = %table-spec;
}

#| Add migration operations
method add-operation($operation, $target, $spec) {
    %!migration-spec<operations>.push: {
        operation => $operation,
        target => $target,
        spec => $spec
    };
}

#| Execute the migration
method execute-migration() {
    # Convert migration spec to MigrationManager format
    my %manager-spec = self!convert-to-manager-spec();
    
    # Use MigrationManager to execute
    start-multi-step-migration($!migration-name, %manager-spec);
}

#| Convert internal spec to MigrationManager format
method !convert-to-manager-spec() {
    my %spec;
    %spec<description> = $!migration-description if $!migration-description;
    
    # Process operations and convert to manager spec format
    for %!migration-spec<operations>.list -> %op {
        given %op<operation> {
            when 'new-column' {
                my $table = %op<target>;
                my %column-spec = %op<spec>;
                %spec<new-columns>{$table} //= %();
                for %column-spec.kv -> $column, %def {
                    %spec<new-columns>{$table}{$column} = %def;
                }
            }
            when 'new-index' {
                my $table = %op<target>;
                my %index-spec = %op<spec>;
                %spec<new-indexes>{$table} //= [];
                %spec<new-indexes>{$table}.push: %index-spec;
            }
            when 'new-table' {
                my $table = %op<target>;
                my %table-spec = %op<spec>;
                %spec<new-tables>{$table} = %table-spec;
            }
            when 'populate' {
                my $table = %op<target>;
                my %populate-spec = %op<spec>;
                %spec<population>{$table} = %populate-spec;
            }
            when 'delete-column' {
                my $table = %op<target>;
                my @columns = %op<spec><columns> || [%op<spec><column>];
                %spec<delete-columns>{$table} //= [];
                %spec<delete-columns>{$table}.append: @columns;
            }
            when 'delete-index' {
                my %index-spec = %op<spec>;
                %spec<delete-indexes> //= [];
                %spec<delete-indexes>.push: %index-spec;
            }
            when 'new-foreign-key' {
                my $table = %op<target>;
                my %fk-spec = %op<spec>;
                %spec<new-foreign-keys>{$table} //= [];
                %spec<new-foreign-keys>{$table}.push: %fk-spec;
            }
            when 'new-check-constraint' {
                my $table = %op<target>;
                my %check-spec = %op<spec>;
                %spec<new-check-constraints>{$table} //= [];
                %spec<new-check-constraints>{$table}.push: %check-spec;
            }
            when 'delete-table' {
                my $table = %op<target>;
                %spec<delete-tables> //= [];
                %spec<delete-tables>.push: $table;
            }
        }
    }
    
    %spec
}

#| Generate migration from model differences (auto-migration)
method generate-from-models($old-model, $new-model) {
    # Get column differences
    my %old-columns = $old-model.^columns.map: { .name.substr(2) => $_ };
    my %new-columns = $new-model.^columns.map: { .name.substr(2) => $_ };
    
    my $table-name = $new-model.^table;
    
    # Find new columns
    for %new-columns.keys -> $col-name {
        unless %old-columns{$col-name} {
            my $attr = %new-columns{$col-name};
            my %col-spec = self!column-spec-from-attr($attr);
            self.add-operation('new-column', $table-name, { $col-name => %col-spec });
        }
    }
    
    # Find deleted columns  
    for %old-columns.keys -> $col-name {
        unless %new-columns{$col-name} {
            self.add-operation('delete-column', $table-name, { column => $col-name });
        }
    }
    
    # TODO: Detect index differences, constraint changes, etc.
}

#| Extract column specification from attribute
method !column-spec-from-attr($attr) {
    my %spec;
    
    # Get type information
    my $type = $attr.type;
    given $type {
        when Str { %spec<type> = 'VARCHAR(255)' }
        when Int { %spec<type> = 'INTEGER' }
        when Bool { %spec<type> = 'BOOLEAN' }
        when DateTime { %spec<type> = 'TIMESTAMP' }
        default { %spec<type> = 'TEXT' }
    }
    
    # Check column traits/args
    if $attr.can('args') {
        my %args = $attr.args;
        %spec<nullable> = %args<nullable> if %args<nullable>:exists;
        %spec<unique> = %args<unique> if %args<unique>;
        %spec<primary-key> = True if %args<id>;
        %spec<auto-increment> = True if %args<auto-increment>;
    }
    
    %spec
}

#| Add migration method to models
method add-migrate-method($model-class) {
    my method migrate($from-model) {
        my $migration = MetamodelX::Red::MigrationHOW.new_type(
            name => "{$model-class.^name}-migration",
            description => "Auto-generated migration from {$from-model.^name} to {$model-class.^name}"
        );
        
        $migration.HOW.generate-from-models($from-model, $model-class);
        $migration.HOW.execute-migration();
    }
    
    $model-class.^add_method('migrate', $method);
}