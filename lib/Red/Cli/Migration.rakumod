use v6;

#| CLI tooling for Red migration management
unit class Red::Cli::Migration;

use Red::MigrationManager;
use Red::MigrationStatus;

#| Generate a new migration template
method generate-migration(Str $name, Str :$type = 'column-change') {
    my $timestamp = DateTime.now.format('%Y%m%d%H%M%S');
    my $filename = "migrations/{$timestamp}-{$name}.raku";
    
    my $template = self!get-migration-template($type, $name);
    
    unless $filename.IO.parent.d {
        $filename.IO.parent.mkdir;
    }
    
    $filename.IO.spurt($template);
    say "Generated migration: $filename";
    $filename
}

#| Start a migration from file
method start-migration-from-file(Str $filename) {
    unless $filename.IO.f {
        die "Migration file not found: $filename";
    }
    
    my $migration-code = $filename.IO.slurp;
    
    # Evaluate the migration code in a safe context
    my %spec = EVAL $migration-code;
    my $name = self!extract-migration-name($filename);
    
    start-multi-step-migration($name, %spec);
    say "Started migration: $name";
}

#| Advance a specific migration
method advance-migration(Str $name) {
    my $result = advance-migration($name);
    say $result;
}

#| Advance all pending migrations
method advance-all-migrations() {
    my @statuses = list-migration-status();
    my $advanced = 0;
    
    for @statuses -> %migration {
        if %migration<phase> ne 'COMPLETED' {
            try {
                advance-migration(%migration<name>);
                $advanced++;
                say "Advanced migration: %migration<name>";
            }
            CATCH {
                default {
                    say "Failed to advance migration %migration<name>: {.message}";
                }
            }
        }
    }
    
    say "$advanced migrations advanced";
}

#| Show migration status
method show-status() {
    my @statuses = list-migration-status();
    
    if @statuses.elems == 0 {
        say "No migrations found";
        return;
    }
    
    say "Migration Status:";
    say "=" x 60;
    
    for @statuses -> %migration {
        say "%migration<name>:";
        say "  Phase: %migration<phase>";
        say "  Created: %migration<created>";
        say "  Time in phase: %migration<time-in-phase>s";
        say "  Description: %migration<description>";
        say "";
    }
}

#| Check deployment safety
method safety-check() {
    my @warnings = check-deployment-safety();
    
    if @warnings.elems == 0 {
        say "✅ Safe to deploy";
        return 0;
    } else {
        say "⚠️  Deployment warnings:";
        for @warnings -> $warning {
            say "  - $warning";
        }
        return 1;
    }
}

#| Get migration template based on type
method !get-migration-template(Str $type, Str $name) {
    given $type {
        when 'column-change' {
            return qq:to/TEMPLATE/;
            # Migration: $name
            # Generated: {DateTime.now}
            
            use Red::MigrationManager;
            
            migration "$name" => \{
                description "Add description here";
                
                # Add new columns
                new-columns table_name => \{
                    new_column => \{ type => "VARCHAR(255)" \}
                \};
                
                # Populate new columns (optional)
                populate table_name => \{
                    new_column => "old_column"  # or complex expression
                \};
                
                # Make columns NOT NULL (optional)
                make-not-null \{ table => "table_name", column => "new_column" \};
                
                # Delete old columns (optional)
                delete-columns table_name => ["old_column"];
            \};
            TEMPLATE
        }
        when 'table-change' {
            return qq:to/TEMPLATE/;
            # Migration: $name
            # Generated: {DateTime.now}
            
            use Red::MigrationManager;
            
            migration "$name" => \{
                description "Add description here";
                
                # Create new tables
                new-tables new_table => \{
                    columns => \{
                        id => \{ type => "SERIAL PRIMARY KEY" \},
                        name => \{ type => "VARCHAR(255) NOT NULL" \}
                    \}
                \};
                
                # Create indexes
                new-indexes new_table => [
                    \{ columns => ["name"], unique => False \}
                ];
                
                # Add foreign keys (optional)
                new-foreign-keys => [
                    \{
                        table => "new_table",
                        column => "user_id",
                        ref-table => "users", 
                        ref-column => "id"
                    \}
                ];
                
                # Delete old tables (optional)
                delete-tables => ["old_table"];
            \};
            TEMPLATE
        }
        default {
            die "Unknown migration type: $type";
        }
    }
}

#| Extract migration name from filename
method !extract-migration-name(Str $filename) {
    my $basename = $filename.IO.basename;
    # Remove timestamp prefix and .raku extension
    $basename ~~ s/^ \d+ '-' //;
    $basename ~~ s/ '.' \w+ $ //;
    $basename
}

# Export CLI functions
sub migration-generate(Str $name, Str :$type = 'column-change') is export {
    Red::Cli::Migration.generate-migration($name, :$type);
}

sub migration-start(Str $filename) is export {
    Red::Cli::Migration.start-migration-from-file($filename);
}

sub migration-advance(Str $name) is export {
    Red::Cli::Migration.advance-migration($name);
}

sub migration-advance-all() is export {
    Red::Cli::Migration.advance-all-migrations();
}

sub migration-status() is export {
    Red::Cli::Migration.show-status();
}

sub migration-safety-check() is export {
    Red::Cli::Migration.safety-check();
}