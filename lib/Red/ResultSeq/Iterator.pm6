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
                $k => try {
                    $!driver.inflate(
                        %cols{$k}.inflate.($v),
                        :to($!of."$k"().attr.type)
                    )
                } // (%cols{$k} ?? %cols{$k}.inflate.($v) !! $v)
            } else { Empty }
        }).Hash)
    ;
    $obj.^clean-up;
    return .($obj) with &!post;
    $obj
}
