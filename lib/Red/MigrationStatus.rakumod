use v6;
use Red;

#| Track the status of multi-step migrations in the database
unit model Red::MigrationStatus is table<red_migration_status>;

has UInt $.id is id;
has Str $.migration-name is column(:unique) is required;
has Str $.current-phase is column is required;
has Instant $.created-at is column = now;
has Instant $.updated-at is column = now;
has Instant $.phase-started-at is column = now;
has Str $.description is column;

#| Get status for a migration, creating if it doesn't exist
method get-status(Str $migration-name) {
    my $status = self.^all.grep(*.migration-name eq $migration-name).head;
    
    unless $status {
        $status = self.^create: :$migration-name, :current-phase('BEFORE-START');
    }
    
    $status
}

#| Advance migration to next phase
method advance-to(Str $next-phase) {
    self.current-phase = $next-phase;
    self.updated-at = now;
    self.phase-started-at = now;
    self.^save;
}

#| Check if migration is in a specific phase
method is-in-phase(Str $phase) {
    self.current-phase eq $phase
}

#| Check if migration is completed
method is-completed() {
    self.current-phase eq 'COMPLETED'
}

#| Get all active (non-completed) migrations
method all-active-migrations() {
    self.^all.grep(*.current-phase ne 'COMPLETED')
}

#| Get time spent in current phase
method time-in-current-phase() {
    now - self.phase-started-at
}

#| Set migration description
method set-description(Str $description) {
    self.description = $description;
    self.updated-at = now;
    self.^save;
}

#| Get human-readable status
method status-summary() {
    "Migration '{self.migration-name}' is in phase '{self.current-phase}' " ~
    "(started {self.phase-started-at}, {self.time-in-current-phase.Int}s ago)"
}