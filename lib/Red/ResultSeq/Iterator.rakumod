use Red::DB;
use Red::AST;
use Red::Driver;
use Red::Utils;
use Red::QueryPlan;
use Red::QueryPlan::Cache;
unit class Red::ResultSeq::Iterator does Iterator;
has Mu:U        $.of            is required;
has Red::AST    $.ast           is required;
has             &.post;
has             $!st-handler;
has Red::Driver $.driver        = get-RED-DB;
has Red::QueryPlan::Cache $.plan-cache .= new;

submethod TWEAK(|) {
    my $ast = $!ast;
    note $ast if $*RED-DEBUG-AST;
    my $enabled = try $*RED-QUERY-PLAN-CACHE;
    my @st-handler;
    if !$!driver.supports-query-plans {
        @st-handler = $!driver.prepare($!driver.optimize($ast));
    } elsif $enabled.WHAT === Bool && !$enabled {
        @st-handler = $!driver.prepare($ast);
    } else {
        my $description = Red::QueryPlan.describe($ast);
        my $cache = $description<shared-cache> // $!plan-cache;
        my $key = $description<key>;
        my $entry = $key.DEFINITE
            ?? $cache.fetch($!driver.WHICH.Str ~ '|' ~ $key, {
                $!driver.compile-query($ast, :parameters($description<parameters>))
            })
            !! ('fallback' => $!driver.compile-query($ast,
                :parameters($description<parameters>)));
        my $report = try $*RED-COMPILER-REPORT;
        $report(:status('plan-' ~ $entry.key), :reason($description<reasons>.join(', ')))
            if $report ~~ Callable;
        @st-handler = $!driver.prepare($entry.value,
            :parameters($description<parameters>), :comments($description<comments>));
    }

    @st-handler>>.execute unless $*RED-DRY-RUN;
    $!st-handler = @st-handler.tail;
    $!of.^emit: $ast;
    CATCH {
        default {
            $!of.^emit: $ast, :error($_);
            proceed
        }
    }
}

#method is-lazy { True }

method pull-one {
    if $*RED-DRY-RUN { return $!of.bless }
    my $data := $!st-handler.row;
    return IterationEnd if $data =:= IterationEnd or not $data;
    my $obj = $!of.^new-from-data($data);
    $obj.^clean-up;
    $obj.^saved-on-db;
    return .($obj) with &!post;
    $obj
}
