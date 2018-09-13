use Red::AST;
unit class Red::DoneResultSeq is Seq;

sub run-query(:$of, $filter) {
}

class ResultSeq::Iterator does Iterator {
    has Mu:U        $.of            is required;
    has Red::AST    $.filter        is required;
    has             $!st-handler    = run-query :$!of, :$!filter;

    method pull-one {
        # $!of.bless: |transform $!st-handler.row: :hash
        $!of.bless
    }
}

has Mu:U        $.of;
has Red::AST    $.filter;

method new(:$of, :$filter) {
    ::?CLASS.bless: :$of, :$filter
}

method iterator {
    ResultSeq::Iterator.new: :$!of, :$!filter
}
