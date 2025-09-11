# Example demonstrating file-per-version pattern for versioned models
# 
# This shows how to organize model versions in separate files
# and use them with Red's migration system

use v6;
use lib 'lib';

# Mock separate file structure for example
# In real usage, these would be in separate .rakumod files

# File: lib/Models/User-v1.rakumod
BEGIN {
    EVAL q:to/END/;
        use Red;
        
        model User:ver<1.0> {
            has Int $.id is serial;
            has Str $.name is column;
            has Int $.age is column;
        }
    END
}

# File: lib/Models/User-v2.rakumod  
BEGIN {
    EVAL q:to/END/;
        use Red;
        
        model User:ver<2.0> {
            has Int $.id is serial;
            has Str $.name is column;
            has Str $.email is column;
            has Int $.age is column;
        }
    END
}

# Usage in migration code
use Red::ModelRegistry;

say "=== File-per-Version Model Example ===";

# Load model versions (simulating require-model-version)
my $user-v1 = get-model-version('User', '1.0');
my $user-v2 = get-model-version('User', '2.0');

say "Loaded User v1.0: {$user-v1.^name}";
say "Loaded User v2.0: {$user-v2.^name}";

# List all User versions
my %versions = list-model-versions('User');
say "Available User versions: {%versions.keys.sort}";

# Get latest version
my $latest = get-latest-model-version('User');
say "Latest User version: {$latest.^name}";

# Compare versions for migration planning
my %comparison = compare-model-versions($user-v1, $user-v2);
say "Migration path: {%comparison<from>} → {%comparison<to>}";

# Example of how migrations could be set up
# (This would integrate with the existing migration system)
say "\n=== Migration Setup Example ===";
say "Setting up migration from v1.0 to v2.0...";
say "- v2.0 adds email column";
say "- Migration would populate email from name transformation";

# This demonstrates the conceptual approach
# Real implementation would use the ^migrate method
if $user-v2.^can('migrate') {
    $user-v2.^migrate(from => $user-v1);
    say "Migration defined successfully";
} else {
    say "Migration definition ready (^migrate method would be used)";
}

say "\n=== File Organization ===";
say "Recommended structure:";
say "lib/";
say "├── Models/";
say "│   ├── User-v1.rakumod    # User:ver<1.0>";
say "│   ├── User-v2.rakumod    # User:ver<2.0>";
say "│   └── User-v3.rakumod    # User:ver<3.0>";
say "└── Migrations/";
say "    ├── user-v1-to-v2.raku";
say "    └── user-v2-to-v3.raku";

say "\n=== Benefits ===";
say "✓ Native Raku :ver<> syntax";
say "✓ No redeclaration errors";  
say "✓ Clean file organization";
say "✓ Easy version management";
say "✓ Seamless Red integration";