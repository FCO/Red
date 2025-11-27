use v6;

#| Individual phase management for multi-step migrations
unit class Red::MigrationPhase;

has Str $.name is required;
has Str $.description;
has Callable $.validator;
has Callable $.executor;
has Instant $.scheduled-time;
has Duration $.min-time-between-phases = Duration.new(300); # 5 minutes default

#| Check if this phase can be executed
method can-execute() {
    # Check if enough time has passed since last phase
    if $!scheduled-time && now < $!scheduled-time {
        return False;
    }
    
    # Run custom validator if provided
    if $!validator {
        return $!validator();
    }
    
    True
}

#| Execute this phase
method execute() {
    die "Phase '{$!name}' cannot be executed at this time" unless self.can-execute;
    
    if $!executor {
        $!executor();
    } else {
        die "No executor defined for phase '{$!name}'";
    }
}

#| Schedule this phase for future execution
method schedule(Instant $when) {
    $!scheduled-time = $when;
}

#| Schedule this phase to run after minimum delay
method schedule-after-delay() {
    $!scheduled-time = now + $!min-time-between-phases;
}

#| Create a phase for adding columns
method create-add-columns-phase(Str $migration-name, %column-specs) {
    self.new:
        name => "add-columns-$migration-name",
        description => "Add new nullable columns for migration $migration-name",
        executor => {
            for %column-specs.kv -> $table, %columns {
                for %columns.kv -> $column, %spec {
                    my $sql = "ALTER TABLE $table ADD COLUMN $column {%spec<type> // 'VARCHAR(255)'} NULL";
                    $*RED-DB.execute($sql);
                }
            }
        }
}

#| Create a phase for populating columns
method create-populate-columns-phase(Str $migration-name, %population-specs) {
    self.new:
        name => "populate-columns-$migration-name",
        description => "Populate new columns for migration $migration-name",
        executor => {
            for %population-specs.kv -> $table, %transformations {
                for %transformations.kv -> $column, $transformation {
                    # This would need to handle Red AST transformations
                    my $sql = "UPDATE $table SET $column = $transformation";
                    $*RED-DB.execute($sql);
                }
            }
        }
}

#| Create a phase for dropping columns
method create-drop-columns-phase(Str $migration-name, %drop-specs) {
    self.new:
        name => "drop-columns-$migration-name", 
        description => "Drop old columns for migration $migration-name",
        executor => {
            for %drop-specs.kv -> $table, @columns {
                for @columns -> $column {
                    my $sql = "ALTER TABLE $table DROP COLUMN $column";
                    $*RED-DB.execute($sql);
                }
            }
        }
}