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
has             $!st-handler;

submethod TWEAK(|) {
    my Red::Driver $driver = $*RED-DB // die Q[$*RED-DB wasn't defined];
    my ($sql, @bind) := $driver.translate: $driver.optimize: Red::AST::Select.new: :$!of, :$!filter, :$!limit, :@!order;

    unless $*RED-DRY-RUN {
        $!st-handler = $driver.prepare: $sql;
        $!st-handler.execute: |@bind
    }
}

method pull-one {
    if $*RED-DRY-RUN { return $!of.bless }
    my $data := $!st-handler.row;
    return IterationEnd if $data =:= IterationEnd or not $data;
    my $obj = $!of.new: |%$data;
    $obj.^clean-up;
    return .($obj) with &!post;
    $obj
}
