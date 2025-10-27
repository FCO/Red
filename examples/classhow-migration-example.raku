#!/usr/bin/env raku

use Red :api<2>;
use Red::Migration::DSL;

# Example showing the ClassHOW-based migration syntax requested by @FCO

#| User's desired syntax - ClassHOW based migration
migration user-security-upgrade {
    table users {
        new-column hashed_password { :type<VARCHAR>, :255size }
        new-column is_active { :type<bool>, :default }
        new-indexes :columns["email"], :unique
        populate -> $new, $old {
            $new.hashed_password = "hash:" ~ $old.plain_password
        }
        delete-columns <plain_password>;
    }
}

#| Alternative syntax examples
migration comprehensive-example {
    # Create new table
    new-table audit_log {
        id { :type<SERIAL>, :primary-key }
        table_name { :type<VARCHAR>, :100size }
        action { :type<VARCHAR>, :50size }
        created_at { :type<TIMESTAMP>, :default("NOW()") }
    }
    
    # Modify existing table
    table users {
        # Add columns with various syntaxes
        new-column full_name { :type<VARCHAR>, :200size, :!nullable }
        new-column last_login { :type<TIMESTAMP>, :nullable }
        new-column status { :type<VARCHAR>, :20size, :default("active") }
        
        # Add indexes
        new-indexes :columns["full_name", "status"];
        new-indexes :columns["last_login"];
        new-indexes :columns["email"], :unique;
        
        # Add constraints
        new-foreign-key :column<department_id>, :references-table<departments>, :references-column<id>;
        new-check-constraint :name<valid_status>, :expression<"status IN ('active', 'inactive', 'pending')">;
        
        # Populate with Red::AST
        populate full_name => {
            ast => ast-concat(
                ast-column("first_name"),
                ast-literal(" "),
                ast-column("last_name")
            )
        };
        
        # Populate with simple expressions
        populate last_login => "NOW()";
        populate status => "'active'";
        
        # Complex population with block
        populate -> $new, $old {
            $new.full_name = $old.first_name ~ " " ~ $old.last_name;
            $new.last_login = DateTime.now if $old.active;
            $new.status = $old.active ?? "active" !! "inactive";
        };
        
        # Remove old columns
        delete-columns <first_name last_name active>;
    }
    
    # Remove old tables
    delete-tables <old_user_data temp_migration_table>;
}

#| Auto-migration from model differences
model UserV1 is model-version('User:1.0') {
    has Int $.id is serial;
    has Str $.email is column;
    has Str $.first-name is column;
    has Str $.last-name is column;
    has Str $.plain-password is column;
    has Bool $.active is column;
}

model UserV2 is model-version('User:2.0') {
    has Int $.id is serial;  
    has Str $.email is column;
    has Str $.full-name is column;
    has Str $.hashed-password is column;
    has Bool $.is-active is column;
    has DateTime $.last-login is column { nullable => True };
    has Str $.status is column { default => 'active' };
}

# Auto-generate migration from model differences
UserV2.^migrate(from => UserV1);

#| Migration-aware application code
class UserService {
    method authenticate(UserV2 $user, Str $password) {
        # Handle migration state automatically
        handle-migration "user-security-upgrade",
            read-new-return-defined => {
                return $user if $user.hashed-password eq self.hash($password);
                Nil
            },
            read-old => {
                return $user if $user.plain-password eq $password;
                Nil  
            };
    }
    
    method hash(Str $password) {
        # Simplified hash function for example
        "hash:" ~ $password
    }
}

#| Usage examples
say "Migration examples created successfully!";

# Check migration status
my @status = migration-status();
say "Active migrations: " ~ @status.elems;

# Advance migrations
advance-migration("user-security-upgrade");

# Safety check before deployment
my @unsafe = migration-safety-check();
if @unsafe {
    say "Unsafe to deploy: " ~ @unsafe.join(", ");
} else {
    say "Safe to deploy!";
}