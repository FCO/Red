#!/usr/bin/env raku
# Run ALL Red tests with Code::Coverage and update .coverage file

use Code::Coverage;

my $red-dir = "/root/forks/Red".IO;

# Collect ALL .rakutest files
my @tests = dir($red-dir.add("t"), test => / '.rakutest' $/).map(*.absolute).sort;

# Collect ALL .rakumod files under lib/
my @targets = do for dir($red-dir.add("lib"), :recursive, test => / '.rakumod' | '.pm6' $/) {
    .absolute
}

# Filter targets: only files that actually exist and have coverable lines
@targets = @targets.grep(*.IO.f);

say "Targets: {@targets.elems} lib files";
say "Tests:   {@tests.elems} test files";

# Use prove6-style runner — run each test file individually 
my $cov = Code::Coverage.new(
    :@targets,
    :runners(@tests),
    :extra["-I", $red-dir.add("lib").absolute],
);

$cov.run;

# Calculate total coverage
my $coverable = $cov.num-coverable-lines;
my $covered   = $cov.num-covered-lines;

say "";
say "═" x 50;
say "Coverable lines: $coverable";
say "Covered lines:   $covered";
say "Coverage:        {sprintf '%.1f%%', 100 * $covered / $coverable}" if $coverable;

# Show per-file coverage
say "";
say "═" x 50;
say "Per-file coverage:";
for $cov.coverage.sort(*.key) -> (:$key, :$value) {
    say "  {$value // 'N/A'}  $key";
}

# Show missed lines summary
say "";
say "═" x 50;
say "Files with missed lines:";
for $cov.missed.sort(*.value.elems).reverse -> (:$key, :$value) {
    next unless $value.elems;
    say "  {$value.elems} missed — $key";
}

# Write the percentage to .coverage (numeric only)
if $coverable {
    my $pct = (100 * $covered / $coverable).round;
    $red-dir.add(".coverage").spurt($pct.Str);
    say "";
    say "Updated .coverage → $pct%";
}
