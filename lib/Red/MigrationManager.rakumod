use v6;

#| Migration manager for coordinating multi-step migrations
unit class Red::MigrationManager;

use Red::MultiStepMigration;
use Red::MigrationStatus;
use Red::MigrationPhase;

has %.active-migrations;
has $.auto-advance = False;
has $.safety-checks = True;

#| Start a new multi-step migration
method start-migration(Str $name, %spec) {
    my $status = Red::MigrationStatus.get-status($name);
    
    if $status.current-phase ne 'BEFORE-START' {
        die "Migration '$name' is already in progress (phase: {$status.current-phase})";
    }
    
    # Validate migration specification
    self!validate-migration-spec(%spec);
    
    # Store migration spec
    %!active-migrations{$name} = %spec;
    
    $status.set-description(%spec<description> // "Multi-step migration: $name");
    
    "Migration '$name' initialized"
}

#| Advance a migration to the next phase
method advance-migration(Str $name) {
    my $status = Red::MigrationStatus.get-status($name);
    my %spec = %!active-migrations{$name} // die "Migration '$name' not found";
    
    given $status.current-phase {
        when 'BEFORE-START' {
            self!execute-phase-1($name, %spec);
            $status.advance-to('CREATED-COLUMNS');
            "Phase 1 complete: Added new nullable columns for migration '$name'"
        }
        when 'CREATED-COLUMNS' {
            self!execute-phase-2($name, %spec); 
            $status.advance-to('POPULATED-COLUMNS');
            "Phase 2 complete: Populated new columns for migration '$name'"
        }
        when 'POPULATED-COLUMNS' {
            self!execute-phase-3($name, %spec);
            $status.advance-to('DELETED-COLUMNS');
            "Phase 3 complete: Made columns NOT NULL and deleted old columns for migration '$name'"
        }
        when 'DELETED-COLUMNS' {
            $status.advance-to('COMPLETED');
            %!active-migrations{$name}:delete;
            "Migration '$name' completed successfully"
        }
        default {
            die "Migration '$name' is in invalid state: {$status.current-phase}"
        }
    }
}

#| Get status of all migrations
method list-migrations() {
    my @results;
    for Red::MigrationStatus.^all -> $status {
        @results.push: {
            name => $status.migration-name,
            phase => $status.current-phase,
            created => $status.created-at,
            updated => $status.updated-at,
            time-in-phase => $status.time-in-current-phase,
            description => $status.description
        }
    }
    @results
}

#| Check if it's safe to deploy new code
method deployment-safety-check() {
    my @unsafe;
    
    for Red::MigrationStatus.all-active-migrations -> $migration {
        given $migration.current-phase {
            when 'CREATED-COLUMNS' {
                @unsafe.push: "Migration '{$migration.migration-name}' requires code that handles both old and new columns";
            }
            when 'POPULATED-COLUMNS' {
                @unsafe.push: "Migration '{$migration.migration-name}' is ready for code that uses only new columns";
            }
        }
    }
    
    @unsafe
}

#| Phase 1: Create new nullable columns
method !execute-phase-1(Str $name, %spec) {
    my %new-columns = %spec<new-columns> // %();
    
    for %new-columns.kv -> $table, %columns {
        for %columns.kv -> $column, %column-spec {
            my $type = %column-spec<type> // 'VARCHAR(255)';
            my $sql = "ALTER TABLE $table ADD COLUMN $column $type NULL";
            
            try {
                $*RED-DB.execute($sql);
            }
            CATCH {
                default {
                    die "Failed to add column $column to table $table: {.message}";
                }
            }
        }
    }
}

#| Phase 2: Populate new columns
method !execute-phase-2(Str $name, %spec) {
    my %population = %spec<population> // %();
    
    for %population.kv -> $table, %transformations {
        for %transformations.kv -> $column, $transformation {
            # Handle different types of transformations
            my $sql = self!build-population-sql($table, $column, $transformation);
            
            try {
                $*RED-DB.execute($sql);
            }
            CATCH {
                default {
                    die "Failed to populate column $column in table $table: {.message}";
                }
            }
        }
    }
    
    # Make columns NOT NULL if specified
    my @make-not-null = %spec<make-not-null> // ();
    for @make-not-null -> %column-spec {
        my $table = %column-spec<table>;
        my $column = %column-spec<column>;
        my $sql = "ALTER TABLE $table ALTER COLUMN $column SET NOT NULL";
        
        try {
            $*RED-DB.execute($sql);
        }
        CATCH {
            default {
                die "Failed to set column $column NOT NULL in table $table: {.message}";
            }
        }
    }
}

#| Phase 3: Drop old columns
method !execute-phase-3(Str $name, %spec) {
    my %delete-columns = %spec<delete-columns> // %();
    
    for %delete-columns.kv -> $table, @columns {
        for @columns -> $column {
            my $sql = "ALTER TABLE $table DROP COLUMN $column";
            
            try {
                $*RED-DB.execute($sql);
            }
            CATCH {
                default {
                    die "Failed to drop column $column from table $table: {.message}";
                }
            }
        }
    }
}

#| Build SQL for populating columns with transformations
method !build-population-sql($table, $column, $transformation) {
    given $transformation {
        when Str {
            # Simple string transformation - assumes it's a SQL expression
            "UPDATE $table SET $column = $transformation"
        }
        when Hash {
            # Complex transformation specification
            my $expression = $transformation<expression> // die "No expression in transformation";
            my $where = $transformation<where> ?? " WHERE {$transformation<where>}" !! "";
            "UPDATE $table SET $column = $expression$where"
        }
        default {
            die "Unsupported transformation type: {$transformation.^name}";
        }
    }
}

#| Validate migration specification
method !validate-migration-spec(%spec) {
    # Check required sections exist
    unless %spec<new-columns> || %spec<delete-columns> {
        die "Migration must specify either new-columns or delete-columns";
    }
    
    # Validate new columns specification
    if %spec<new-columns> {
        for %spec<new-columns>.kv -> $table, %columns {
            for %columns.kv -> $column, %column-spec {
                unless %column-spec<type> {
                    warn "No type specified for column $column in table $table, will use VARCHAR(255)";
                }
            }
        }
    }
    
    # Validate population specifications match new columns
    if %spec<population> && %spec<new-columns> {
        for %spec<population>.kv -> $table, %transformations {
            for %transformations.keys -> $column {
                unless %spec<new-columns>{$table}{$column} {
                    die "Population specified for column $column in table $table, but column not defined in new-columns";
                }
            }
        }
    }
}

# Global migration manager instance
my $global-manager = Red::MigrationManager.new;

# Export convenience functions
sub start-multi-step-migration(Str $name, %spec) is export {
    $global-manager.start-migration($name, %spec)
}

sub advance-migration(Str $name) is export {
    $global-manager.advance-migration($name)
}

sub list-migration-status() is export {
    $global-manager.list-migrations()
}

sub check-deployment-safety() is export {
    $global-manager.deployment-safety-check()
}

# Syntactic sugar for migration specifications
my %*MIGRATION-SPEC;

sub migration(Str $name, &block) is export {
    %*MIGRATION-SPEC = %();
    &block();
    start-multi-step-migration($name, %*MIGRATION-SPEC);
}

sub description(Str $desc) is export {
    %*MIGRATION-SPEC<description> = $desc;
}

sub new-columns(Str $table, %columns) is export {
    %*MIGRATION-SPEC<new-columns>{$table} = %columns;
}

sub new-tables(Str $table, %spec) is export {
    %*MIGRATION-SPEC<new-tables>{$table} = %spec;
}

sub new-indexes(Str $table, @indexes) is export {
    %*MIGRATION-SPEC<new-indexes>{$table} = @indexes;
}

sub populate(Str $table, %transformations) is export {
    %*MIGRATION-SPEC<population>{$table} = %transformations;
}

sub make-not-null(%spec) is export {
    %*MIGRATION-SPEC<make-not-null>.push: %spec;
}

sub delete-columns(Str $table, @columns) is export {
    %*MIGRATION-SPEC<delete-columns>{$table} = @columns;
}

sub delete-indexes(@indexes) is export {
    %*MIGRATION-SPEC<delete-indexes> = @indexes;
}

sub delete-tables(@tables) is export {
    %*MIGRATION-SPEC<delete-tables> = @tables;
}