#!/usr/bin/env raku
# CI-friendly coverage runner — uses prove6 as single runner for ALL tests
use Code::Coverage;

my $root = "/home/runner/work/Red/Red".IO;  # GitHub Actions path

# All lib modules
my @targets = do for dir($root.add("lib"), :recursive, test => / '.rakumod' $/) {
    .absolute
}

say "Measuring coverage for {@targets.elems} modules...";

my $cov = Code::Coverage.new(
    :@targets,
    :runners["prove6"],
    :extra["-I", $root.add("lib").absolute, "-l", "-j1", $root.add("t").absolute],
);

$cov.run;

my $coverable = $cov.num-coverable-lines;
my $covered   = $cov.num-covered-lines;

if $coverable {
    my $pct = (100 * $covered / $coverable).round;
    say "Coverage: $pct% ($covered/$coverable lines)";
    $root.add(".coverage").spurt($pct.Str);
} else {
    note "No coverable lines found!";
    exit 1;
}
