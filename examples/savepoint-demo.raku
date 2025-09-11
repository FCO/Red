#!/usr/bin/env raku

use lib 'lib';
use Red:api<2>;

model Person is rw {
    has Int $.id is serial;
    has Str $.name is column;
}

# Set up database
my $*RED-DB = database "SQLite";
Person.^create-table;

say "=== SAVEPOINT Demo ===";
say "";

# Demonstrate nested transactions with savepoints
say "1. Starting main transaction...";
my $main-tx = $*RED-DB.begin;

{
    my $*RED-DB = $main-tx;
    my $person1 = Person.^create(:name("Alice"));
    say "   Created person: { $person1.name } (ID: { $person1.id })";
    
    say "2. Starting nested transaction (savepoint)...";
    my $nested-tx = $main-tx.begin;
    
    {
        my $*RED-DB = $nested-tx;
        my $person2 = Person.^create(:name("Bob"));
        say "   Created person: { $person2.name } (ID: { $person2.id })";
        
        say "   Current count in nested transaction: { Person.^all.elems }";
        
        say "3. Rolling back nested transaction...";
        $nested-tx.rollback;
    }
    
    say "   Current count after rollback: { Person.^all.elems }";
    say "   Remaining people: { Person.^all.map(*.name).join(', ') }";
    
    say "4. Committing main transaction...";
    $main-tx.commit;
}

say "   Final count: { Person.^all.elems }";
say "   Final people: { Person.^all.map(*.name).join(', ') }";

say "";
say "=== Manual Savepoint Demo ===";

# Demonstrate manual savepoint operations
{
    my $tx = $*RED-DB.begin;
    my $*RED-DB = $tx;
    
    my $person3 = Person.^create(:name("Charlie"));
    say "Created { $person3.name }";
    
    # Create a manual savepoint
    $*RED-DB.savepoint("manual_sp");
    say "Created savepoint 'manual_sp'";
    
    my $person4 = Person.^create(:name("David"));
    say "Created { $person4.name }";
    
    say "Count before rollback: { Person.^all.elems }";
    
    # Rollback to savepoint
    $*RED-DB.rollback-to-savepoint("manual_sp");
    say "Rolled back to savepoint";
    
    say "Count after rollback: { Person.^all.elems }";
    say "People: { Person.^all.map(*.name).join(', ') }";
    
    $tx.commit;
}

say "";
say "Demo complete!";