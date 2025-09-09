use v6;

#| Multi-step migration system for zero-downtime database migrations
unit class Red::MultiStepMigration;

use Red::MigrationPhase;
use Red::MigrationStatus;

enum MigrationPhase is export <
    BEFORE-START
    CREATED-COLUMNS
    POPULATED-COLUMNS
    DELETED-COLUMNS
    COMPLETED
>;

#| Execute a multi-step migration
method execute-migration($migration-name, %migration-spec) {
    my $status = Red::MigrationStatus.get-status($migration-name);
    
    given $status.current-phase {
        when BEFORE-START {
            self!create-columns($migration-name, %migration-spec);
            $status.advance-to(CREATED-COLUMNS);
        }
        when CREATED-COLUMNS {
            self!populate-columns($migration-name, %migration-spec);
            $status.advance-to(POPULATED-COLUMNS);
        }
        when POPULATED-COLUMNS {
            self!delete-old-columns($migration-name, %migration-spec);
            $status.advance-to(DELETED-COLUMNS);
        }
        when DELETED-COLUMNS {
            $status.advance-to(COMPLETED);
        }
        when COMPLETED {
            # Migration is complete
        }
    }
}

#| Advance migration to next phase
method advance-migration($migration-name) {
    my $status = Red::MigrationStatus.get-status($migration-name);
    
    given $status.current-phase {
        when BEFORE-START {
            self!check-and-advance($migration-name, CREATED-COLUMNS);
        }
        when CREATED-COLUMNS {
            self!check-and-advance($migration-name, POPULATED-COLUMNS);
        }
        when POPULATED-COLUMNS {
            self!check-and-advance($migration-name, DELETED-COLUMNS);
        }
        when DELETED-COLUMNS {
            self!check-and-advance($migration-name, COMPLETED);
        }
        default {
            die "Migration '$migration-name' is already completed or in invalid state";
        }
    }
}

#| Check if migration can advance and do so
method !check-and-advance($migration-name, $next-phase) {
    # Add validation logic here
    my $status = Red::MigrationStatus.get-status($migration-name);
    $status.advance-to($next-phase);
}

#| Create new columns as nullable
method !create-columns($migration-name, %migration-spec) {
    for %migration-spec<new-columns>.kv -> $table, %columns {
        for %columns.kv -> $column, %spec {
            my $sql = self!generate-add-column-sql($table, $column, %spec);
            # Execute SQL to add column
            $*RED-DB.execute($sql);
        }
    }
}

#| Populate new columns with transformed data
method !populate-columns($migration-name, %migration-spec) {
    for %migration-spec<population>.kv -> $table, %transformations {
        for %transformations.kv -> $column, $transformation {
            my $sql = self!generate-population-sql($table, $column, $transformation);
            # Execute SQL to populate column
            $*RED-DB.execute($sql);
        }
    }
    
    # Make columns NOT NULL if specified
    for %migration-spec<make-not-null> -> $column-spec {
        my $sql = self!generate-alter-not-null-sql($column-spec);
        $*RED-DB.execute($sql);
    }
}

#| Delete old columns
method !delete-old-columns($migration-name, %migration-spec) {
    for %migration-spec<delete-columns>.kv -> $table, @columns {
        for @columns -> $column {
            my $sql = self!generate-drop-column-sql($table, $column);
            $*RED-DB.execute($sql);
        }
    }
}

#| Generate SQL to add a column
method !generate-add-column-sql($table, $column, %spec) {
    my $type = %spec<type> // 'VARCHAR(255)';
    my $nullable = %spec<nullable> // True;
    my $null-clause = $nullable ?? 'NULL' !! 'NOT NULL';
    
    "ALTER TABLE $table ADD COLUMN $column $type $null-clause"
}

#| Generate SQL to populate a column
method !generate-population-sql($table, $column, $transformation) {
    # This would need to be more sophisticated to handle Red AST transformations
    "UPDATE $table SET $column = $transformation"
}

#| Generate SQL to make column NOT NULL
method !generate-alter-not-null-sql(%spec) {
    my $table = %spec<table>;
    my $column = %spec<column>;
    "ALTER TABLE $table ALTER COLUMN $column SET NOT NULL"
}

#| Generate SQL to drop a column
method !generate-drop-column-sql($table, $column) {
    "ALTER TABLE $table DROP COLUMN $column"
}

#| Get migration status for use in handle-migration
method get-migration-status($migration-name) {
    Red::MigrationStatus.get-status($migration-name).current-phase
}

# Global instance
my $global-migration-manager = Red::MultiStepMigration.new;

#| Handle migration in user code - switches behavior based on migration phase
sub handle-migration($migration-name, *%handlers) is export {
    my $phase = $global-migration-manager.get-migration-status($migration-name);
    
    given $phase {
        when BEFORE-START | DELETED-COLUMNS | COMPLETED {
            # Use old column behavior
            if %handlers<read-old> {
                return %handlers<read-old>()
            } elsif %handlers<write-old> {
                return %handlers<write-old>()
            }
        }
        when CREATED-COLUMNS {
            # Try new columns first, fall back to old
            if %handlers<read-new-return-defined> {
                my $result = %handlers<read-new-return-defined>();
                return $result if $result.defined;
            }
            if %handlers<read-old> {
                return %handlers<read-old>()
            }
            
            # For writes, write to both
            if %handlers<write-new> && %handlers<write-old> {
                %handlers<write-old>();
                return %handlers<write-new>();
            }
        }
        when POPULATED-COLUMNS {
            # Use new columns
            if %handlers<read-new> {
                return %handlers<read-new>()
            } elsif %handlers<write-new> {
                return %handlers<write-new>()
            }
        }
    }
    
    die "No appropriate handler found for migration '$migration-name' in phase $phase"
}

#| Set up migration status in %*RED-MIGRATION dynamic variable
sub setup-migration-context() is export {
    my %*RED-MIGRATION;
    for Red::MigrationStatus.all-active-migrations() -> $migration {
        %*RED-MIGRATION{$migration.name} = $migration.current-phase;
    }
}