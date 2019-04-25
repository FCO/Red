use Red::DB;
use Red::AST;
use Red::Driver;
use Red::Utils;
unit class Red::ResultSeq::Iterator does Iterator;
has Mu:U        $.of            is required;
has Red::AST    $.ast           is required;
has             &.post;
has             $!st-handler;
has Red::Driver $!driver = get-RED-DB;

submethod TWEAK(|) {
    my $ast = $!driver.optimize: $!ast;
    my ($sql, @bind) := do given $!driver.translate: $ast { .key, .value }

    unless $*RED-DRY-RUN {
        $!st-handler = $!driver.prepare: $sql;
        $!st-handler.execute: |@bind
    }
}

#method is-lazy { True }

method pull-one {
    if $*RED-DRY-RUN { return $!of.bless }
    my $data := $!st-handler.row;
    return IterationEnd if $data =:= IterationEnd or not $data;
    my %cols = $!of.^columns.map: { .column.attr-name => .column }
    my $obj = $!of.new: |(%($data).kv
        .map(-> $k, $v {
            do with $v {
                my $c = $k.split(".").tail;
                CATCH {
                    dd $data;
                    dd %cols;
                    dd $c;
                    dd %cols{$c};
                    dd $!driver.^lookup("inflate").candidates>>.signature;
                    .rethrow
                }
                die "Column '$k' not found" without %cols{$c};
                die "Inflator not defined for column '$k'" without %cols{$c}.inflate;
                my $inflated = %cols{$c}.inflate.($v);
                $inflated = $!driver.inflate(
                    %cols{$c}.inflate.($v),
                    :to($!of.^attributes.first(*.name.substr(2) eq $c).type)
                ) if \($!driver, $inflated, :to($!of.^attributes.first(*.name.substr(2) eq $c).type)) ~~ $!driver.^lookup("inflate").candidates.any.signature;
                $c => $inflated
            } else { Empty }
        }).Hash)
    ;
    $obj.^clean-up;
    $obj.^saved-on-db;
    return .($obj) with &!post;
    $obj
}
