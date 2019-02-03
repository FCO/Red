use Red::AST;
use Red::Driver;
use Red::AST::Select;
unit class Red::ResultSeq::Iterator does Iterator;
has Mu:U        $.of            is required;
has Red::AST    $.ast           is required;
has             &.post;
has             $!st-handler;
has Red::Driver $!driver = $*RED-DB // die Q[$*RED-DB wasn't defined];

submethod TWEAK(|) {
    my $ast = $!driver.optimize: $!ast;
    my ($sql, @bind) := $!driver.translate: $ast;

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
    my %cols = $!of.^columns.keys.map: { .column.attr-name => .column }
    my $obj = $!of.new: |(%($data).kv
        .map(-> $k, $v {
            do with $v {
                CATCH {
                    dd $data;
                    dd %cols;
                    dd $!driver.^lookup("inflate").candidates>>.signature;
                    .rethrow
                }
                die "Column '$k' not found" without %cols{$k.gist};
                die "Inflator not defined for column '$k'" without %cols{$k}.inflate;
                my $inflated = %cols{$k}.inflate.($v);
                $inflated = $!driver.inflate(
                    %cols{$k}.inflate.($v),
                    :to($!of."$k"().attr.type)
                ) if \($!driver, $inflated, :to($!of."$k"().attr.type)) ~~ $!driver.^lookup("inflate").candidates.any.signature;
                $k => $inflated
            } else { Empty }
        }).Hash)
    ;
    $obj.^clean-up;
    return .($obj) with &!post;
    $obj
}
