#!/usr/bin/env raku

=begin pod

=head1 Multi-Step Migration Example

This example demonstrates how to use Red's multi-step migration system
for zero-downtime database migrations. Based on the design discussion
in GitHub issue #15.

=head2 The Problem

You have a User model that stores passwords in plain text and want to
migrate to hashed passwords without downtime.

=head2 The Solution

Use a 5-phase migration process:
1. Add new nullable columns (hashed_password, expired)
2. Deploy code that handles both old and new columns
3. Populate new columns, make them NOT NULL
4. Deploy code that only uses new columns
5. Remove old columns

=end pod

use Red;
use Red::MultiStepMigration;
use Red::MigrationManager;

# Set up database connection
my $*RED-DB = database "SQLite", :database<migration_example.db>;

# Original model (before migration)
model User is table<user> {
    has UInt $.id is id;
    has Str $.nick is column;
    has Str $.plain-password is column;  # Will be removed
    has Str $.hashed-password is column is nullable;  # Will be added
    has Bool $.expired is column is nullable;  # Will be added
    
    # Example of using handle-migration in methods
    method save-password(Str $new-password) {
        handle-migration "password-hash-migration",
            write-old => {
                $!plain-password = $new-password;
            },
            write-new => {
                $!hashed-password = hash-password($new-password);
                $!expired = False;
            };
        self.^save;
    }
    
    method authenticate(Str $password) {
        handle-migration "password-hash-migration",
            read-new-return-defined => {
                return self if $!hashed-password && $!hashed-password eq hash-password($password);
                Nil
            },
            read-old => {
                return self if $!plain-password && $!plain-password eq $password;
                Nil
            };
    }
}

# Simple password hashing function (use a real one in production!)
sub hash-password(Str $password) {
    "hashed:" ~ $password
}

sub MAIN(Str $command = 'demo') {
    given $command {
        when 'demo' { run-demo() }
        when 'start' { start-migration() }
        when 'advance' { advance-migration-phase() }
        when 'status' { show-migration-status() }
        when 'safety' { check-safety() }
        default { say "Unknown command: $command" }
    }
}

#| Run complete demonstration
sub run-demo() {
    say "=== Multi-Step Migration Demo ===\n";
    
    # Create tables and initial data
    setup-initial-data();
    
    say "Step 1: Starting migration...";
    start-migration();
    
    say "\nStep 2: Phase 1 - Adding nullable columns...";
    advance-migration-phase();
    
    say "\nStep 3: Phase 2 - Populating new columns...";
    advance-migration-phase();
    
    say "\nStep 4: Phase 3 - Removing old columns...";
    advance-migration-phase();
    
    say "\nStep 5: Completing migration...";
    advance-migration-phase();
    
    say "\n=== Migration Complete! ===";
    show-final-state();
}

#| Set up initial database state
sub setup-initial-data() {
    # Create tables
    User.^create-table;
    Red::MigrationStatus.^create-table;
    
    # Add some test users
    User.^create: :nick<alice>, :plain-password<secret123>;
    User.^create: :nick<bob>, :plain-password<password456>;
    User.^create: :nick<charlie>, :plain-password<mypass789>;
    
    say "Created initial users with plain text passwords";
}

#| Start the migration process
sub start-migration() {
    my %migration-spec = {
        description => "Migrate from plain text to hashed passwords",
        new-columns => {
            user => {
                hashed_password => { type => "VARCHAR(255)" },
                expired => { type => "BOOLEAN DEFAULT 0" }
            }
        },
        population => {
            user => {
                hashed_password => "CONCAT('hashed:', plain_password)",
                expired => "0"
            }
        },
        make-not-null => [
            { table => "user", column => "hashed_password" },
            { table => "user", column => "expired" }
        ],
        delete-columns => {
            user => ["plain_password"]
        }
    };
    
    try {
        my $result = start-multi-step-migration("password-hash-migration", %migration-spec);
        say $result;
    }
    CATCH {
        default { say "Error starting migration: {.message}" }
    }
}

#| Advance migration to next phase
sub advance-migration-phase() {
    try {
        my $result = advance-migration("password-hash-migration");
        say $result;
        
        # Show safety warnings after each phase
        my @warnings = check-deployment-safety();
        if @warnings {
            say "\n⚠️  Deployment Safety Warnings:";
            for @warnings -> $warning {
                say "   - $warning";
            }
        }
    }
    CATCH {
        default { say "Error advancing migration: {.message}" }
    }
}

#| Show current migration status
sub show-migration-status() {
    say "=== Migration Status ===";
    
    my @migrations = list-migration-status();
    
    if @migrations {
        for @migrations -> %migration {
            say "Migration: %migration<name>";
            say "  Phase: %migration<phase>";
            say "  Description: %migration<description>";
            say "  Created: %migration<created>";
            say "  Time in current phase: {%migration<time-in-phase>.Int}s";
            say "";
        }
    } else {
        say "No migrations found";
    }
}

#| Check deployment safety
sub check-safety() {
    say "=== Deployment Safety Check ===";
    
    my @warnings = check-deployment-safety();
    
    if @warnings {
        say "⚠️  Warnings found:";
        for @warnings -> $warning {
            say "   - $warning";
        }
    } else {
        say "✅ Safe to deploy";
    }
}

#| Show final state after migration
sub show-final-state() {
    say "=== Final Database State ===";
    
    # Test that the migration code works
    my $alice = User.^all.grep(*.nick eq 'alice').head;
    if $alice {
        say "Testing Alice's authentication...";
        
        # This should work using the new hashed password system
        my $auth-result = $alice.authenticate('secret123');
        say $auth-result ?? "✅ Authentication works!" !! "❌ Authentication failed";
        
        # Test saving a new password
        $alice.save-password('newsecret');
        say "✅ Password update works!";
    }
    
    show-migration-status();
}