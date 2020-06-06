use Red::DB;
use Red::AST;
use Red::Driver;
use Red::Utils;
unit class Red::ResultSeq::Iterator does Iterator;
has Mu:U        $.of            is required;
has Red::AST    $.ast           is required;
has             &.post;
has             $!st-handler;
has Red::Driver $.driver        = get-RED-DB;

submethod TWEAK(|) {
    my $ast = $!driver.optimize: $!ast;
    my @st-handler = $!driver.prepare: $ast;

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
