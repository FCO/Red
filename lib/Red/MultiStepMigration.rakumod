use v6;

#| Multi-step migration system for zero-downtime database migrations
unit class Red::MultiStepMigration;

use Red::MigrationPhase;
use Red::MigrationStatus;
use Red::AST::CreateTable;
use Red::AST::CreateColumn;
use Red::AST::DropColumn;
use Red::AST::Function;
use Red::AST::Infix;
use Red::AST::Value;

enum MigrationPhase is export <
    BEFORE-START
    CREATED-TABLES
    CREATED-COLUMNS
    CREATED-INDEXES
    POPULATED-COLUMNS
    UPDATED-CONSTRAINTS
    DELETED-COLUMNS
    DELETED-INDEXES
    DELETED-TABLES
    COMPLETED
>;

#| Execute a multi-step migration
method execute-migration($migration-name, %migration-spec) {
    my $status = Red::MigrationStatus.get-status($migration-name);
    
    given $status.current-phase {
        when BEFORE-START {
            self!create-tables($migration-name, %migration-spec);
            $status.advance-to(CREATED-TABLES);
        }
        when CREATED-TABLES {
            self!create-columns($migration-name, %migration-spec);
            $status.advance-to(CREATED-COLUMNS);
        }
        when CREATED-COLUMNS {
            self!create-indexes($migration-name, %migration-spec);
            $status.advance-to(CREATED-INDEXES);
        }
        when CREATED-INDEXES {
            self!populate-columns($migration-name, %migration-spec);
            $status.advance-to(POPULATED-COLUMNS);
        }
        when POPULATED-COLUMNS {
            self!update-constraints($migration-name, %migration-spec);
            $status.advance-to(UPDATED-CONSTRAINTS);
        }
        when UPDATED-CONSTRAINTS {
            self!delete-old-columns($migration-name, %migration-spec);
            $status.advance-to(DELETED-COLUMNS);
        }
        when DELETED-COLUMNS {
            self!delete-indexes($migration-name, %migration-spec);
            $status.advance-to(DELETED-INDEXES);
        }
        when DELETED-INDEXES {
            self!delete-tables($migration-name, %migration-spec);
            $status.advance-to(DELETED-TABLES);
        }
        when DELETED-TABLES {
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
            self!check-and-advance($migration-name, CREATED-TABLES);
        }
        when CREATED-TABLES {
            self!check-and-advance($migration-name, CREATED-COLUMNS);
        }
        when CREATED-COLUMNS {
            self!check-and-advance($migration-name, CREATED-INDEXES);
        }
        when CREATED-INDEXES {
            self!check-and-advance($migration-name, POPULATED-COLUMNS);
        }
        when POPULATED-COLUMNS {
            self!check-and-advance($migration-name, UPDATED-CONSTRAINTS);
        }
        when UPDATED-CONSTRAINTS {
            self!check-and-advance($migration-name, DELETED-COLUMNS);
        }
        when DELETED-COLUMNS {
            self!check-and-advance($migration-name, DELETED-INDEXES);
        }
        when DELETED-INDEXES {
            self!check-and-advance($migration-name, DELETED-TABLES);
        }
        when DELETED-TABLES {
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

#| Create new tables
method !create-tables($migration-name, %migration-spec) {
    for %migration-spec<new-tables>.kv -> $table, %table-spec {
        my $sql = self!generate-create-table-sql($table, %table-spec);
        $*RED-DB.execute($sql);
    }
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

#| Create new indexes
method !create-indexes($migration-name, %migration-spec) {
    for %migration-spec<new-indexes>.kv -> $table, @indexes {
        for @indexes -> %index-spec {
            my $sql = self!generate-create-index-sql($table, %index-spec);
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

#| Update constraints (foreign keys, checks, etc.)
method !update-constraints($migration-name, %migration-spec) {
    # Add foreign key constraints
    for %migration-spec<new-foreign-keys> -> %fk-spec {
        my $sql = self!generate-add-foreign-key-sql(%fk-spec);
        $*RED-DB.execute($sql);
    }
    
    # Add check constraints
    for %migration-spec<new-check-constraints> -> %check-spec {
        my $sql = self!generate-add-check-constraint-sql(%check-spec);
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

#| Delete old indexes
method !delete-indexes($migration-name, %migration-spec) {
    for %migration-spec<delete-indexes> -> %index-spec {
        my $sql = self!generate-drop-index-sql(%index-spec);
        $*RED-DB.execute($sql);
    }
}

#| Delete old tables
method !delete-tables($migration-name, %migration-spec) {
    for %migration-spec<delete-tables> -> $table {
        my $sql = self!generate-drop-table-sql($table);
        $*RED-DB.execute($sql);
    }
}

#| Generate SQL to create a table using Red AST
method !generate-create-table-sql($table, %spec) {
    # Try to use Red AST for better SQL generation
    if %spec<ast> && %spec<ast><columns> {
        my $ast = Red::AST::CreateTable.new(
            name => $table,
            columns => %spec<ast><columns>,
            temp => %spec<temp> // False
        );
        return $ast.sql($*RED-DB.formatter);
    }
    
    # Fallback to manual SQL generation
    my $columns = %spec<columns>.map({
        my ($name, %col-spec) = $_.kv;
        my $type = %col-spec<type> // 'VARCHAR(255)';
        my $nullable = %col-spec<nullable> // True;
        my $null-clause = $nullable ?? 'NULL' !! 'NOT NULL';
        "$name $type $null-clause"
    }).join(', ');
    
    "CREATE TABLE $table ($columns)"
}

#| Generate SQL to add a column using Red AST when possible
method !generate-add-column-sql($table, $column, %spec) {
    # Try to use Red AST for better SQL generation
    if %spec<ast> {
        my $ast = Red::AST::CreateColumn.new(
            table => $table,
            name => $column,
            type => %spec<type> // 'VARCHAR(255)',
            nullable => %spec<nullable> // True
        );
        return $ast.sql($*RED-DB.formatter);
    }
    
    # Fallback to manual SQL generation
    my $type = %spec<type> // 'VARCHAR(255)';
    my $nullable = %spec<nullable> // True;
    my $null-clause = $nullable ?? 'NULL' !! 'NOT NULL';
    
    "ALTER TABLE $table ADD COLUMN $column $type $null-clause"
}

#| Generate SQL to create an index
method !generate-create-index-sql($table, %spec) {
    my $index-name = %spec<name> // "{$table}_idx_{ %spec<columns>.join('_') }";
    my $columns = %spec<columns>.join(', ');
    my $unique = %spec<unique> ?? 'UNIQUE ' !! '';
    
    "CREATE {$unique}INDEX $index-name ON $table ($columns)"
}

#| Generate SQL to populate a column with AST support
method !generate-population-sql($table, $column, $transformation) {
    given $transformation {
        when Str {
            # Simple string transformation - assumes it's a SQL expression
            "UPDATE $table SET $column = $transformation"
        }
        when Hash {
            # Complex transformation specification
            if $transformation<ast> {
                # Use Red AST for complex expressions
                my $expression = $transformation<ast>;
                my $where-clause = $transformation<where-ast> ?? 
                    " WHERE {$transformation<where-ast>.sql($*RED-DB.formatter)}" !! "";
                "UPDATE $table SET $column = {$expression.sql($*RED-DB.formatter)}$where-clause"
            } else {
                # Fallback to string expressions
                my $expression = $transformation<expression> // die "No expression in transformation";
                my $where = $transformation<where> ?? " WHERE {$transformation<where>}" !! "";
                "UPDATE $table SET $column = $expression$where"
            }
        }
        when Red::AST {
            # Direct AST transformation
            "UPDATE $table SET $column = {$transformation.sql($*RED-DB.formatter)}"
        }
        default {
            die "Unsupported transformation type: {$transformation.^name}";
        }
    }
}

#| Generate SQL to make column NOT NULL
method !generate-alter-not-null-sql(%spec) {
    my $table = %spec<table>;
    my $column = %spec<column>;
    "ALTER TABLE $table ALTER COLUMN $column SET NOT NULL"
}

#| Generate SQL to add foreign key constraint
method !generate-add-foreign-key-sql(%spec) {
    my $table = %spec<table>;
    my $column = %spec<column>;
    my $ref-table = %spec<ref-table>;
    my $ref-column = %spec<ref-column>;
    my $constraint-name = %spec<name> // "{$table}_fk_{$column}";
    
    "ALTER TABLE $table ADD CONSTRAINT $constraint-name FOREIGN KEY ($column) REFERENCES $ref-table ($ref-column)"
}

#| Generate SQL to add check constraint
method !generate-add-check-constraint-sql(%spec) {
    my $table = %spec<table>;
    my $constraint-name = %spec<name>;
    my $condition = %spec<condition>;
    
    "ALTER TABLE $table ADD CONSTRAINT $constraint-name CHECK ($condition)"
}

#| Generate SQL to drop a column
method !generate-drop-column-sql($table, $column) {
    "ALTER TABLE $table DROP COLUMN $column"
}

#| Generate SQL to drop an index
method !generate-drop-index-sql(%spec) {
    my $index-name = %spec<name>;
    "DROP INDEX $index-name"
}

#| Generate SQL to drop a table
method !generate-drop-table-sql($table) {
    "DROP TABLE $table"
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
        when BEFORE-START | DELETED-COLUMNS | DELETED-INDEXES | DELETED-TABLES | COMPLETED {
            # Use old column behavior
            if %handlers<read-old> {
                return %handlers<read-old>()
            } elsif %handlers<write-old> {
                return %handlers<write-old>()
            }
        }
        when CREATED-TABLES | CREATED-COLUMNS | CREATED-INDEXES {
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
        when POPULATED-COLUMNS | UPDATED-CONSTRAINTS {
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