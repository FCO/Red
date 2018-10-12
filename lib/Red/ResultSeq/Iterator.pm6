use Red::AST;
use Red::Column;
use Red::Driver;
use Red::AST::Select;
unit class Red::ResultSeq::Iterator does Iterator;
has Mu:U        $.of            is required;
has Red::AST    $.filter        is required;
has Int         $.limit;
has Red::Column @.order;
has             &.post;
has             @.table-list;
has             $!st-handler;
has Red::Driver $!driver = $*RED-DB // die Q[$*RED-DB wasn't defined];

submethod TWEAK(|) {
    my ($sql, @bind) := $!driver.translate: $!driver.optimize: Red::AST::Select.new: :$!of, :$!filter, :$!limit, :@!order, :@!table-list;

    unless $*RED-DRY-RUN {
        $!st-handler = $!driver.prepare: $sql;
        $!st-handler.execute: |@bind
    }
}

method pull-one {
    if $*RED-DRY-RUN { return $!of.bless }
    my $data := $!st-handler.row;
    return IterationEnd if $data =:= IterationEnd or not $data;
    my %cols = $!of.^columns.keys.map: { .column.attr-name => .column }
    my $obj = $!of.new: |(%($data).kv
        .map(-> $k, $v {
            do with $v {
                $k => $!driver.inflate: %cols{$k}.inflate.($v), :to($!of."$k"().attr.type)
            } else { Empty }
        }).Hash)
    ;
    $obj.^clean-up;
    return .($obj) with &!post;
    $obj
}
