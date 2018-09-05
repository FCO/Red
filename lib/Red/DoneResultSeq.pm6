use Red::AST;
unit class Red::DoneResultSeq is Seq;

has Mu:U        $.of;
has Red::AST    $.filter;

method new(:$of, :$filter) {
    ::?CLASS.bless: :$of, :$filter
}

method iterator {
    ($!of.new xx 10).iterator
}
