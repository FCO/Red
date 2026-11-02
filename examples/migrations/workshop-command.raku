#!/usr/bin/env raku
my $root = %*ENV<WORKSHOP_ROOT> // '/opt/workshop';
exit (run $*EXECUTABLE, "$root/workshop.raku", |@*ARGS).exitcode;
