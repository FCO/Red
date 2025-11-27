#!/usr/bin/env raku

# Comprehensive example showing the enhanced Red multi-step migration system

use Red;
use Red::ModelRegistry; 
use Red::MigrationManager;
use Red::Cli::Migration;
use Red::AST::Function;
use Red::AST::Infix;
use Red::AST::Value;

# Set up database (using SQLite for the example)
my $*RED-DB = database "SQLite", :database<example.db>;

# Example 1: Trait-based model versioning
model UserV1 is model-version('User:1.0') is table<users> {
    has Int $.id is serial;
    has Str $.name is column;
    has Str $.email is column;
    has Str $.plain_password is column;
}

model UserV2 is model-version('User:2.0') is table<users> {
    has Int $.id is serial;
    has Str $.name is column;
    has Str $.email is column;
    has Str $.hashed_password is column;
    has Bool $.is_active is column;
}

# Example 2: Comprehensive migration using DSL syntax
migration "user-password-security" => {
    description "Migrate from plain text to hashed passwords with activation status";
    
    # Add new columns
    new-columns users => {
        hashed_password => { type => "VARCHAR(255)" },
        is_active => { type => "BOOLEAN DEFAULT TRUE" }
    };
    
    # Create performance indexes
    new-indexes users => [
        { columns => ["email"], unique => True },
        { columns => ["is_active", "created_at"] }
    ];
    
    # Populate using Red AST for type safety
    populate users => {
        hashed_password => {
            ast => Red::AST::Function.new(
                name => 'CONCAT',
                args => [
                    Red::AST::Value.new(value => 'hash:'),
                    Red::AST::Function.new(name => 'plain_password')
                ]
            )
        }
    };
    
    # Add constraints
    new-foreign-keys => [
        {
            table => "user_sessions",
            column => "user_id", 
            ref-table => "users",
            ref-column => "id"
        }
    ];
    
    new-check-constraints => [
        {
            table => "users",
            name => "valid_email",
            condition => "email LIKE '%@%'"
        }
    ];
    
    # Make new columns NOT NULL
    make-not-null { table => "users", column => "hashed_password" };
    
    # Clean up old columns
    delete-columns users => ["plain_password"];
};

# Example 3: Migration-aware application code
class UserService {
    method authenticate(Str $email, Str $password) {
        my $user = User.^rs.first(*.email eq $email);
        return Nil unless $user;
        
        # Handle migration gracefully
        handle-migration "user-password-security",
            read-new-return-defined => {
                # Use new hashed password system
                return $user if $user.hashed-password eq self.hash-password($password);
                Nil
            },
            read-old => {
                # Fallback to old plain text system during migration
                return $user if $user.plain-password eq $password;
                Nil
            };
    }
    
    method hash-password(Str $password) {
        # Simplified hash function for example
        "hash:$password"
    }
}

# Example 4: CLI-based migration management
sub MAIN(Str $command, *@args) {
    given $command {
        when 'generate' {
            my $name = @args[0] // die "Migration name required";
            my $type = @args[1] // 'column-change';
            migration-generate($name, :$type);
        }
        when 'status' {
            migration-status();
        }
        when 'advance' {
            my $name = @args[0];
            if $name {
                migration-advance($name);
            } else {
                migration-advance-all();
            }
        }
        when 'safety-check' {
            my $exit-code = migration-safety-check();
            exit $exit-code;
        }
        when 'demo' {
            say "Running comprehensive migration demo...";
            
            # Check current status
            say "\n1. Current migration status:";
            migration-status();
            
            # Start the migration
            say "\n2. Starting migration...";
            # Migration is already started by the DSL above
            
            # Show phase progression
            for 1..5 -> $phase {
                say "\n3.$phase. Advancing to next phase...";
                advance-migration("user-password-security");
                
                say "Current phase status:";
                migration-status();
                
                say "Deployment safety check:";
                migration-safety-check();
                
                # Simulate deployment pause
                sleep 1;
            }
            
            say "\n4. Migration completed!";
        }
        default {
            say q:to/USAGE/;
            Usage: example.raku <command> [args]
            
            Commands:
              generate <name> [type]  - Generate migration template
              status                  - Show migration status  
              advance [name]          - Advance migration(s)
              safety-check           - Check deployment safety
              demo                   - Run complete demo
            USAGE
        }
    }
}

# Example 5: Automatic migration dependency detection
sub check-migration-dependencies() {
    # This could be enhanced to build a dependency tree
    my @migrations = list-migration-status();
    my %dependencies;
    
    for @migrations -> %migration {
        # Simple dependency detection based on naming convention
        if %migration<name> ~~ /^ (\w+) '-' (\w+) $/ {
            my $base = $0;
            my $step = $1;
            %dependencies{%migration<name>} = "{$base}-setup" if $step ne 'setup';
        }
    }
    
    %dependencies
}

# If run directly, execute CLI
MAIN(@*ARGS[0] // 'demo', |@*ARGS[1..*]) if $?FILE eq $*PROGRAM-NAME;