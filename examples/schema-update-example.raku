#!/usr/bin/env raku

# Example usage of the new schema.update method
# This demonstrates how to use schema updates for intelligent migration

use Red;
use Red::Schema;

# Set up database connection
red-defaults "SQLite", :database<example.db>;

# Define initial models
model User {
    has Int $.id   is serial;
    has Str $.name is column;
}

model Post {
    has Int $.id      is serial;
    has Int $.user-id is referencing(model => 'User', column => 'id');
    has Str $.title   is column;
    has Str $.content is column;
}

# Create schema
my $schema = schema(User, Post);

# Example 1: Initial creation
say "Creating initial schema...";
$schema.drop;  # Clean slate
$schema.create;

# Add some test data
User.^create: :name("Alice");
User.^create: :name("Bob");

say "Initial users: ", User.^all.map(*.name).join(", ");

# Example 2: Schema update (simulating model changes)
# In real usage, you would modify your model definitions and then call update
say "\nUpdating schema...";
$schema.update;

# Example 3: Idempotent updates
say "Running update again (should be safe/idempotent)...";
$schema.update;

# Example 4: Chaining methods
say "Demonstrating method chaining...";
$schema.update.drop;

say "Schema update example completed successfully!";